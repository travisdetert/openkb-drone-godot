#include "bmp280.h"
#include "esp_log.h"
#include <math.h>
#include <string.h>

static const char *TAG = "bmp280";

/* ── BMP280 registers ─────────────────────────────────── */
#define REG_CALIB00    0x88   /* 26 calibration bytes (0x88..0xA1) */
#define REG_CHIP_ID    0xD0
#define REG_RESET      0xE0
#define REG_STATUS     0xF3
#define REG_CTRL_MEAS  0xF4
#define REG_CONFIG     0xF5
#define REG_PRESS_MSB  0xF7   /* 6 bytes: press(3) + temp(3) */

#define BMP280_CHIP_ID 0x58

/* ── Calibration coefficients (datasheet Table 16) ────── */
static uint16_t dig_T1;
static int16_t  dig_T2, dig_T3;
static uint16_t dig_P1;
static int16_t  dig_P2, dig_P3, dig_P4, dig_P5, dig_P6, dig_P7, dig_P8, dig_P9;

/* ── Module state ─────────────────────────────────────── */
static i2c_port_t s_port;
static uint8_t    s_addr;
static float      s_sea_level_pa = 0.0f;  /* calibrated on first read */
static bool       s_calibrated   = false;

/* ── I2C helpers ──────────────────────────────────────── */

static esp_err_t write_reg(uint8_t reg, uint8_t val)
{
    uint8_t buf[2] = { reg, val };
    return i2c_master_write_to_device(s_port, s_addr, buf, 2, pdMS_TO_TICKS(100));
}

static esp_err_t read_regs(uint8_t start_reg, uint8_t *data, size_t len)
{
    return i2c_master_write_read_device(s_port, s_addr,
                                        &start_reg, 1, data, len,
                                        pdMS_TO_TICKS(100));
}

/* ── Compensation (BMP280 datasheet Section 4.2.3) ────── */

static int32_t t_fine;  /* shared between temp and pressure compensation */

static float compensate_temperature(int32_t adc_T)
{
    int32_t var1 = ((((adc_T >> 3) - ((int32_t)dig_T1 << 1))) * ((int32_t)dig_T2)) >> 11;
    int32_t var2 = (((((adc_T >> 4) - ((int32_t)dig_T1)) * ((adc_T >> 4) - ((int32_t)dig_T1))) >> 12) * ((int32_t)dig_T3)) >> 14;
    t_fine = var1 + var2;
    int32_t T = (t_fine * 5 + 128) >> 8;
    return (float)T / 100.0f;
}

static float compensate_pressure(int32_t adc_P)
{
    int64_t var1 = ((int64_t)t_fine) - 128000;
    int64_t var2 = var1 * var1 * (int64_t)dig_P6;
    var2 = var2 + ((var1 * (int64_t)dig_P5) << 17);
    var2 = var2 + (((int64_t)dig_P4) << 35);
    var1 = ((var1 * var1 * (int64_t)dig_P3) >> 8) + ((var1 * (int64_t)dig_P2) << 12);
    var1 = (((((int64_t)1) << 47) + var1)) * ((int64_t)dig_P1) >> 33;

    if (var1 == 0) return 0.0f; /* avoid division by zero */

    int64_t p = 1048576 - adc_P;
    p = (((p << 31) - var2) * 3125) / var1;
    var1 = (((int64_t)dig_P9) * (p >> 13) * (p >> 13)) >> 25;
    var2 = (((int64_t)dig_P8) * p) >> 19;
    p = ((p + var1 + var2) >> 8) + (((int64_t)dig_P7) << 4);

    return (float)((uint32_t)p) / 256.0f;
}

/* ── Public API ───────────────────────────────────────── */

esp_err_t bmp280_init(i2c_port_t port, uint8_t addr)
{
    s_port = port;
    s_addr = addr;

    /* Verify chip ID */
    uint8_t chip_id = 0;
    esp_err_t err = read_regs(REG_CHIP_ID, &chip_id, 1);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to read chip ID");
        return err;
    }
    ESP_LOGI(TAG, "Chip ID = 0x%02X (expected 0x%02X)", chip_id, BMP280_CHIP_ID);

    /* Soft reset */
    err = write_reg(REG_RESET, 0xB6);
    if (err != ESP_OK) return err;
    vTaskDelay(pdMS_TO_TICKS(10));

    /* Read calibration data (26 bytes from 0x88) */
    uint8_t calib[26];
    err = read_regs(REG_CALIB00, calib, 26);
    if (err != ESP_OK) return err;

    dig_T1 = (uint16_t)(calib[1]  << 8 | calib[0]);
    dig_T2 = (int16_t) (calib[3]  << 8 | calib[2]);
    dig_T3 = (int16_t) (calib[5]  << 8 | calib[4]);
    dig_P1 = (uint16_t)(calib[7]  << 8 | calib[6]);
    dig_P2 = (int16_t) (calib[9]  << 8 | calib[8]);
    dig_P3 = (int16_t) (calib[11] << 8 | calib[10]);
    dig_P4 = (int16_t) (calib[13] << 8 | calib[12]);
    dig_P5 = (int16_t) (calib[15] << 8 | calib[14]);
    dig_P6 = (int16_t) (calib[17] << 8 | calib[16]);
    dig_P7 = (int16_t) (calib[19] << 8 | calib[18]);
    dig_P8 = (int16_t) (calib[21] << 8 | calib[20]);
    dig_P9 = (int16_t) (calib[23] << 8 | calib[22]);

    /* Config: standby 0.5ms, IIR filter coeff 4 */
    err = write_reg(REG_CONFIG, (0x00 << 5) | (0x02 << 2));  /* t_sb=0.5ms, filter=4 */
    if (err != ESP_OK) return err;

    /* Ctrl_meas: pressure x4, temperature x1, normal mode */
    err = write_reg(REG_CTRL_MEAS, (0x01 << 5) | (0x03 << 2) | 0x03);
    if (err != ESP_OK) return err;

    s_calibrated = false;
    ESP_LOGI(TAG, "BMP280 initialised (press x4, temp x1, IIR=4, normal mode)");
    return ESP_OK;
}

esp_err_t bmp280_read(bmp280_data_t *data)
{
    uint8_t raw[6];
    esp_err_t err = read_regs(REG_PRESS_MSB, raw, 6);
    if (err != ESP_OK) return err;

    /* 20-bit ADC values */
    int32_t adc_P = ((int32_t)raw[0] << 12) | ((int32_t)raw[1] << 4) | ((int32_t)raw[2] >> 4);
    int32_t adc_T = ((int32_t)raw[3] << 12) | ((int32_t)raw[4] << 4) | ((int32_t)raw[5] >> 4);

    data->temperature_c = compensate_temperature(adc_T);
    data->pressure_pa   = compensate_pressure(adc_P);

    /* Calibrate sea-level reference on first valid read */
    if (!s_calibrated && data->pressure_pa > 30000.0f) {
        s_sea_level_pa = data->pressure_pa;
        s_calibrated = true;
        ESP_LOGI(TAG, "Sea-level pressure calibrated: %.1f Pa", s_sea_level_pa);
    }

    /* Barometric altitude: alt = 44330 * (1 - (P/P0)^(1/5.255)) */
    if (s_sea_level_pa > 0.0f) {
        data->altitude_m = 44330.0f * (1.0f - powf(data->pressure_pa / s_sea_level_pa, 1.0f / 5.255f));
    } else {
        data->altitude_m = 0.0f;
    }

    return ESP_OK;
}
