#include "mpu6050.h"
#include "esp_log.h"
#include <string.h>

static const char *TAG = "mpu6050";

/* ── MPU6050 registers ────────────────────────────────── */
#define REG_SMPLRT_DIV   0x19
#define REG_CONFIG       0x1A
#define REG_GYRO_CONFIG  0x1B
#define REG_ACCEL_CONFIG 0x1C
#define REG_ACCEL_XOUT_H 0x3B   /* 14-byte burst: accel(6) + temp(2) + gyro(6) */
#define REG_PWR_MGMT_1   0x6B
#define REG_WHO_AM_I     0x75

/* ── Scale factors ────────────────────────────────────── */
/* Gyro FS_SEL=1 → +/-500 dps → 65.5 LSB/dps */
#define GYRO_SCALE   (1.0f / 65.5f)
/* Accel AFS_SEL=1 → +/-4g → 8192 LSB/g */
#define ACCEL_SCALE  (1.0f / 8192.0f)

/* ── Module state ─────────────────────────────────────── */
static i2c_port_t s_port;
static uint8_t    s_addr;

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

/* ── Public API ───────────────────────────────────────── */

esp_err_t mpu6050_init(i2c_port_t port, uint8_t addr)
{
    s_port = port;
    s_addr = addr;

    /* Verify device identity */
    uint8_t who = 0;
    esp_err_t err = read_regs(REG_WHO_AM_I, &who, 1);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to read WHO_AM_I");
        return err;
    }
    ESP_LOGI(TAG, "WHO_AM_I = 0x%02X", who);

    /* Wake up (clear sleep bit), use internal 8MHz oscillator */
    err = write_reg(REG_PWR_MGMT_1, 0x00);
    if (err != ESP_OK) return err;

    /* Sample rate divider: 1kHz / (1+1) = 500Hz */
    err = write_reg(REG_SMPLRT_DIV, 1);
    if (err != ESP_OK) return err;

    /* DLPF config 3: accel 44Hz, gyro 42Hz bandwidth */
    err = write_reg(REG_CONFIG, 0x03);
    if (err != ESP_OK) return err;

    /* Gyro: FS_SEL=1 → +/-500 dps */
    err = write_reg(REG_GYRO_CONFIG, 0x08);
    if (err != ESP_OK) return err;

    /* Accel: AFS_SEL=1 → +/-4g */
    err = write_reg(REG_ACCEL_CONFIG, 0x08);
    if (err != ESP_OK) return err;

    ESP_LOGI(TAG, "MPU6050 initialised (500Hz, +/-500dps, +/-4g)");
    return ESP_OK;
}

esp_err_t mpu6050_read(mpu6050_data_t *data)
{
    uint8_t raw[14];
    esp_err_t err = read_regs(REG_ACCEL_XOUT_H, raw, 14);
    if (err != ESP_OK) return err;

    /* Big-endian int16 → float with scale */
    int16_t ax_raw = (int16_t)((raw[0]  << 8) | raw[1]);
    int16_t ay_raw = (int16_t)((raw[2]  << 8) | raw[3]);
    int16_t az_raw = (int16_t)((raw[4]  << 8) | raw[5]);
    /* raw[6..7] = temperature, skip */
    int16_t gx_raw = (int16_t)((raw[8]  << 8) | raw[9]);
    int16_t gy_raw = (int16_t)((raw[10] << 8) | raw[11]);
    int16_t gz_raw = (int16_t)((raw[12] << 8) | raw[13]);

    data->ax = (float)ax_raw * ACCEL_SCALE;
    data->ay = (float)ay_raw * ACCEL_SCALE;
    data->az = (float)az_raw * ACCEL_SCALE;
    data->gx = (float)gx_raw * GYRO_SCALE;
    data->gy = (float)gy_raw * GYRO_SCALE;
    data->gz = (float)gz_raw * GYRO_SCALE;

    return ESP_OK;
}
