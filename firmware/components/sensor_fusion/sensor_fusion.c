#include "sensor_fusion.h"

#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_timer.h"

#include "mpu6050.h"
#include "bmp280.h"
#include "udp_comm.h"   /* imu_state_t, shared_write_imu */
#include "app_config.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static const char *TAG = "fusion";

/* ── Complementary filter coefficient ─────────────────── */
#define ALPHA 0.98f   /* gyro trust (high-frequency) */

/* ── BMP280 read divider: 500Hz / 20 = 25Hz ──────────── */
#define BARO_DIVIDER 20

/* ── Sensor fusion task ───────────────────────────────── */

static void fusion_task(void *arg)
{
    ESP_LOGI(TAG, "Sensor fusion task starting");

    /* Initialise sensors on the I2C bus (already configured in main) */
    esp_err_t err = mpu6050_init(I2C_MASTER_NUM, MPU6050_ADDR);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "MPU6050 init failed: %s", esp_err_to_name(err));
        vTaskDelete(NULL);
        return;
    }

    err = bmp280_init(I2C_MASTER_NUM, BMP280_ADDR);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "BMP280 init failed: %s", esp_err_to_name(err));
        vTaskDelete(NULL);
        return;
    }

    /* State */
    float pitch_deg = 0.0f;
    float roll_deg  = 0.0f;
    float yaw_deg   = 0.0f;  /* gyro integration only — drifts without magnetometer */
    float altitude_m = 0.0f;
    float prev_alt   = 0.0f;

    int baro_counter = 0;

    const TickType_t period = pdMS_TO_TICKS(1000 / CONTROL_RATE_HZ);
    TickType_t last_wake = xTaskGetTickCount();

    int log_divider = 0;

    while (1) {
        vTaskDelayUntil(&last_wake, period);

        /* ── Read MPU6050 (500Hz) ─────────────────────── */
        mpu6050_data_t imu_raw;
        if (mpu6050_read(&imu_raw) != ESP_OK) continue;

        /* Accelerometer-derived angles (only valid when not accelerating) */
        float accel_pitch = atan2f(-imu_raw.ax, sqrtf(imu_raw.ay * imu_raw.ay + imu_raw.az * imu_raw.az)) * (180.0f / (float)M_PI);
        float accel_roll  = atan2f(imu_raw.ay, imu_raw.az) * (180.0f / (float)M_PI);

        /* Complementary filter: trust gyro for fast changes, accel for drift correction */
        pitch_deg = ALPHA * (pitch_deg + imu_raw.gy * CONTROL_DT) + (1.0f - ALPHA) * accel_pitch;
        roll_deg  = ALPHA * (roll_deg  + imu_raw.gx * CONTROL_DT) + (1.0f - ALPHA) * accel_roll;

        /* Yaw: gyro integration only (no magnetometer) */
        yaw_deg += imu_raw.gz * CONTROL_DT;
        if (yaw_deg > 180.0f)  yaw_deg -= 360.0f;
        if (yaw_deg < -180.0f) yaw_deg += 360.0f;

        /* ── Read BMP280 (25Hz) ───────────────────────── */
        if (++baro_counter >= BARO_DIVIDER) {
            baro_counter = 0;
            bmp280_data_t baro;
            if (bmp280_read(&baro) == ESP_OK) {
                prev_alt = altitude_m;
                altitude_m = baro.altitude_m;
            }
        }

        /* ── Estimate vertical velocity from altitude diff ─ */
        /* Updated at baro rate but held between samples */
        float vy_est = (altitude_m - prev_alt) / (BARO_DIVIDER * CONTROL_DT);

        /* ── Populate shared state ────────────────────── */
        imu_state_t state = {
            .pitch_deg    = pitch_deg,
            .yaw_deg      = yaw_deg,
            .roll_deg     = roll_deg,
            .alt          = altitude_m,
            .vx           = 0.0f,  /* no horizontal velocity estimation without GPS */
            .vy           = vy_est,
            .vz           = 0.0f,
            .hdg          = yaw_deg < 0.0f ? yaw_deg + 360.0f : yaw_deg,
            .spd          = 0.0f,
            .active       = true,
            .timestamp_us = esp_timer_get_time(),
        };
        shared_write_imu(&state);

        /* ── Periodic log ─────────────────────────────── */
        if (++log_divider >= (CONTROL_RATE_HZ / 2)) {
            log_divider = 0;
            ESP_LOGI(TAG, "P=%.1f R=%.1f Y=%.1f ALT=%.2fm VY=%.2f",
                     pitch_deg, roll_deg, yaw_deg, altitude_m, vy_est);
        }
    }
}

void sensor_fusion_start(void)
{
    xTaskCreatePinnedToCore(fusion_task, "fusion", 4096, NULL, 4, NULL, 0);
}
