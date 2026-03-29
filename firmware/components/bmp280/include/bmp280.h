#pragma once

#include <stdint.h>
#include "driver/i2c.h"
#include "esp_err.h"

/**
 * Compensated BMP280 data.
 */
typedef struct {
    float pressure_pa;     /* pressure in Pascals */
    float temperature_c;   /* temperature in Celsius */
    float altitude_m;      /* barometric altitude in metres */
} bmp280_data_t;

/**
 * Initialise the BMP280 on the given I2C port.
 * Reads calibration data, sets oversampling, normal mode, IIR filter.
 * Captures sea-level reference pressure on first read.
 */
esp_err_t bmp280_init(i2c_port_t port, uint8_t addr);

/**
 * Read compensated pressure, temperature, and derived altitude.
 */
esp_err_t bmp280_read(bmp280_data_t *data);
