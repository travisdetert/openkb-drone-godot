#include "attitude_controller.h"

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_timer.h"

#include "pid_controller.h"
#include "motor_mixer.h"
#include "motor_output.h"
#include "udp_comm.h"

/* Import config */
#include "app_config.h"

static const char *TAG = "ctrl";

/* ── PID instances ─────────────────────────────────────── */

/* Outer loop: angle → rate setpoint */
static pid_t s_pitch_angle_pid;
static pid_t s_roll_angle_pid;

/* Inner loop: rate → normalised output */
static pid_t s_pitch_rate_pid;
static pid_t s_roll_rate_pid;

/* Yaw: rate-only */
static pid_t s_yaw_pid;

/* Altitude hold */
static pid_t s_alt_pid;
static float s_alt_setpoint  = 0.0f;
static bool  s_alt_hold_active = false;

/* Previous attitude for numerical rate derivation */
static float s_prev_pitch = 0.0f;
static float s_prev_roll  = 0.0f;
static float s_prev_yaw   = 0.0f;

/* ── Control task ──────────────────────────────────────── */

static void control_task(void *arg)
{
    /* Init PID controllers */
    pid_init(&s_pitch_angle_pid, ANGLE_KP, ANGLE_KI, ANGLE_KD,
             ANGLE_OUT_MIN, ANGLE_OUT_MAX, INTEGRAL_LIMIT * 100.0f);
    pid_init(&s_roll_angle_pid, ANGLE_KP, ANGLE_KI, ANGLE_KD,
             ANGLE_OUT_MIN, ANGLE_OUT_MAX, INTEGRAL_LIMIT * 100.0f);

    pid_init(&s_pitch_rate_pid, RATE_KP, RATE_KI, RATE_KD,
             RATE_OUT_MIN, RATE_OUT_MAX, INTEGRAL_LIMIT);
    pid_init(&s_roll_rate_pid, RATE_KP, RATE_KI, RATE_KD,
             RATE_OUT_MIN, RATE_OUT_MAX, INTEGRAL_LIMIT);

    pid_init(&s_yaw_pid, YAW_KP, YAW_KI, YAW_KD,
             YAW_OUT_MIN, YAW_OUT_MAX, INTEGRAL_LIMIT);

    pid_init(&s_alt_pid, ALT_KP, ALT_KI, ALT_KD,
             ALT_OUT_MIN, ALT_OUT_MAX, ALT_INTEGRAL_LIMIT);

    const TickType_t period = pdMS_TO_TICKS(1000 / CONTROL_RATE_HZ);
    TickType_t last_wake = xTaskGetTickCount();

    int log_divider = 0;

    while (1) {
        vTaskDelayUntil(&last_wake, period);

        imu_state_t imu;
        int64_t age_us;
        shared_read_imu(&imu, &age_us);

        cmd_output_t cmd = {0};
        float motors[4] = {0};

        /* Failsafe: no telemetry for too long */
        if (age_us > (int64_t)FAILSAFE_TIMEOUT_MS * 1000 || !imu.active) {
            /* Zero everything */
            pid_reset(&s_pitch_angle_pid);
            pid_reset(&s_roll_angle_pid);
            pid_reset(&s_pitch_rate_pid);
            pid_reset(&s_roll_rate_pid);
            pid_reset(&s_yaw_pid);
            pid_reset(&s_alt_pid);
            s_alt_hold_active = false;
            motor_output_set(motors);
            shared_write_cmd(&cmd, motors);

            if (++log_divider >= CONTROL_RATE_HZ) {
                log_divider = 0;
                ESP_LOGW(TAG, "FAILSAFE — age=%lldms active=%d",
                         age_us / 1000, imu.active);
            }
            continue;
        }

        /* ── Derive angular rates from successive samples ── */
        float pitch_rate = (imu.pitch_deg - s_prev_pitch) / CONTROL_DT;
        float roll_rate  = (imu.roll_deg  - s_prev_roll)  / CONTROL_DT;
        float yaw_rate   = (imu.yaw_deg   - s_prev_yaw)   / CONTROL_DT;

        /* Handle yaw wraparound */
        if (yaw_rate > 180.0f / CONTROL_DT)  yaw_rate -= 360.0f / CONTROL_DT;
        if (yaw_rate < -180.0f / CONTROL_DT) yaw_rate += 360.0f / CONTROL_DT;

        s_prev_pitch = imu.pitch_deg;
        s_prev_roll  = imu.roll_deg;
        s_prev_yaw   = imu.yaw_deg;

        /* ── Outer loop: angle → desired rate ──────────── */
        /* Setpoint = 0 (level flight) */
        float pitch_rate_sp = pid_update(&s_pitch_angle_pid, 0.0f, imu.pitch_deg, CONTROL_DT);
        float roll_rate_sp  = pid_update(&s_roll_angle_pid,  0.0f, imu.roll_deg,  CONTROL_DT);

        /* ── Inner loop: rate → normalised output ──────── */
        float pitch_out = pid_update(&s_pitch_rate_pid, pitch_rate_sp, pitch_rate, CONTROL_DT);
        float roll_out  = pid_update(&s_roll_rate_pid,  roll_rate_sp,  roll_rate,  CONTROL_DT);

        /* ── Yaw: rate-only, setpoint = 0 (hold heading) ─ */
        float yaw_out = pid_update(&s_yaw_pid, 0.0f, yaw_rate, CONTROL_DT);

        /* ── Altitude hold ────────────────────────────────── */
        if (!s_alt_hold_active) {
            s_alt_setpoint = imu.alt;
            s_alt_hold_active = true;
            pid_reset(&s_alt_pid);
        }

        float alt_correction = pid_update(&s_alt_pid, s_alt_setpoint, imu.alt, CONTROL_DT);
        float vvel_damping   = -ALT_VEL_KP * imu.vy;
        float throttle       = 0.5f + alt_correction + vvel_damping;
        if (throttle < 0.0f) throttle = 0.0f;
        if (throttle > 1.0f) throttle = 1.0f;

        /* ── Build command output ──────────────────────── */
        cmd.throttle = throttle;
        cmd.pitch    = pitch_out;
        cmd.roll     = roll_out;
        cmd.yaw      = yaw_out;

        /* ── Motor mixer ───────────────────────────────── */
        motor_mixer_compute(throttle, roll_out, pitch_out, yaw_out, motors);

        /* ── Write PWM to LEDC ─────────────────────────── */
        motor_output_set(motors);

        /* ── Publish to shared state for UDP TX ────────── */
        shared_write_cmd(&cmd, motors);

        /* ── Periodic log (every 500ms = 250 ticks@500Hz) */
        if (++log_divider >= (CONTROL_RATE_HZ / 2)) {
            log_divider = 0;
            ESP_LOGI(TAG, "P=%.1f R=%.1f Y=%.1f | cmd T=%.2f P=%.3f R=%.3f Y=%.3f | M[%.0f %.0f %.0f %.0f]",
                     imu.pitch_deg, imu.roll_deg, imu.yaw_deg,
                     cmd.throttle, cmd.pitch, cmd.roll, cmd.yaw,
                     motors[0] * 100, motors[1] * 100, motors[2] * 100, motors[3] * 100);
        }
    }
}

void attitude_controller_start(void)
{
    xTaskCreatePinnedToCore(control_task, "control", 4096, NULL, 5, NULL, 1);
}
