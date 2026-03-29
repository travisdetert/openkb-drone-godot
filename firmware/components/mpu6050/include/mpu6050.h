#pragma once

#include <stdint.h>
#include "driver/i2c.h"
#include "esp_err.h"

/**
 * Raw IMU data from MPU6050: accelerometer (g) and gyroscope (deg/s).
 */
typedef struct {
    float ax, ay, az;   /* accelerometer in g */
    float gx, gy, gz;   /* gyroscope in deg/s */
} mpu6050_data_t;

/**
 * Initialise the MPU6050 on the given I2C port.
 * Configures: wake, gyro +/-500 dps, accel +/-4g, DLPF 42Hz, 500Hz sample rate.
 */
esp_err_t mpu6050_init(i2c_port_t port, uint8_t addr);

/**
 * Burst-read accelerometer + gyroscope data.
 */
esp_err_t mpu6050_read(mpu6050_data_t *data);
