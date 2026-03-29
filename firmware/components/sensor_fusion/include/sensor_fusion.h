#pragma once

/**
 * Start the sensor fusion task.
 * Reads MPU6050 at 500Hz, BMP280 at 25Hz, applies complementary filter,
 * and writes fused state to shared_write_imu().
 *
 * Task: priority 4, core 0.
 */
void sensor_fusion_start(void);
