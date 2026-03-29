#pragma once

/* ── Wi-Fi ─────────────────────────────────────────────── */
#define WIFI_SSID           "your-ssid"
#define WIFI_PASS           "your-password"
#define WIFI_MAX_RETRY      10

/* ── UDP ports ─────────────────────────────────────────── */
#define UDP_TELEMETRY_PORT  4210   /* RX from Godot */
#define UDP_COMMAND_PORT    4211   /* TX to Godot   */

/* ── Godot host (for sending commands back) ────────────── */
#define GODOT_HOST_IP       "255.255.255.255"  /* broadcast */

/* ── Control loop ──────────────────────────────────────── */
#define CONTROL_RATE_HZ     500
#define CONTROL_DT          (1.0f / CONTROL_RATE_HZ)
#define TELEMETRY_POLL_HZ   50
#define FAILSAFE_TIMEOUT_MS 200

/* ── PID — Outer loop (angle → rate, deg/s) ────────────── */
#define ANGLE_KP            4.0f
#define ANGLE_KI            0.0f
#define ANGLE_KD            0.0f
#define ANGLE_OUT_MIN       (-200.0f)
#define ANGLE_OUT_MAX       200.0f

/* ── PID — Inner loop (rate → normalised output) ───────── */
#define RATE_KP             0.005f
#define RATE_KI             0.001f
#define RATE_KD             0.0002f
#define RATE_OUT_MIN        (-1.0f)
#define RATE_OUT_MAX        1.0f

/* ── PID — Yaw (rate-only) ─────────────────────────────── */
#define YAW_KP              0.01f
#define YAW_KI              0.005f
#define YAW_KD              0.0f
#define YAW_OUT_MIN         (-1.0f)
#define YAW_OUT_MAX         1.0f

/* ── PID — Altitude hold ──────────────────────────────── */
#define ALT_KP               0.5f
#define ALT_KI               0.1f
#define ALT_KD               0.2f
#define ALT_OUT_MIN          (-0.5f)
#define ALT_OUT_MAX          0.5f
#define ALT_VEL_KP           0.3f    /* vertical velocity damping */
#define ALT_INTEGRAL_LIMIT   0.3f
#define ALT_HOLD_DEFAULT     5.0f    /* meters — initial setpoint */

/* ── Anti-windup ───────────────────────────────────────── */
#define INTEGRAL_LIMIT       0.3f

/* ── Motor output (LEDC PWM) ───────────────────────────── */
#define MOTOR_PWM_FREQ_HZ   50
#define MOTOR_PWM_RES_BITS  16
#define MOTOR_PIN_0          25
#define MOTOR_PIN_1          26
#define MOTOR_PIN_2          27
#define MOTOR_PIN_3          14

/* ── Status LED ────────────────────────────────────────── */
#define STATUS_LED_PIN       2

/* ── I2C bus ───────────────────────────────────────────── */
#define I2C_MASTER_NUM       I2C_NUM_0
#define I2C_SDA_PIN          21
#define I2C_SCL_PIN          22
#define I2C_FREQ_HZ          400000  /* 400kHz fast mode */

/* ── MPU6050 (IMU) ────────────────────────────────────── */
#define MPU6050_ADDR         0x68

/* ── BMP280 (barometer) ───────────────────────────────── */
#define BMP280_ADDR          0x76    /* SDO→GND; use 0x77 if SDO→VCC */

/* ── Sensor source ────────────────────────────────────── */
#define USE_REAL_SENSORS     0       /* 0 = simulator telemetry, 1 = hardware I2C */

/* ── Protocol ─────────────────────────────────────────── */
#define USE_BINARY_PROTOCOL  1   /* 1 = binary framing, 0 = JSON */
