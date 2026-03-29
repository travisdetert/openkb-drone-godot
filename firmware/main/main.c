#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "esp_log.h"
#include "nvs_flash.h"

#include "app_config.h"
#include "wifi_manager.h"
#include "udp_comm.h"
#include "attitude_controller.h"
#include "motor_output.h"
#include "status_led.h"

#if USE_REAL_SENSORS
#include "driver/i2c.h"
#include "sensor_fusion.h"
#endif

static const char *TAG = "main";

/* ── Shared state protected by mutex ───────────────────── */
static SemaphoreHandle_t s_state_mutex;

static imu_state_t  s_imu   = {0};
static cmd_output_t s_cmd   = {0};
static float        s_motors[4] = {0};

/* Timestamp of last good telemetry packet */
static int64_t s_last_telem_us = 0;

/* ── Accessors (mutex-guarded) ─────────────────────────── */

void shared_write_imu(const imu_state_t *imu)
{
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    s_imu = *imu;
    s_last_telem_us = esp_timer_get_time();
    xSemaphoreGive(s_state_mutex);
}

void shared_read_imu(imu_state_t *out, int64_t *age_us)
{
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    *out = s_imu;
    *age_us = esp_timer_get_time() - s_last_telem_us;
    xSemaphoreGive(s_state_mutex);
}

void shared_write_cmd(const cmd_output_t *cmd, const float motors[4])
{
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    s_cmd = *cmd;
    memcpy(s_motors, motors, sizeof(s_motors));
    xSemaphoreGive(s_state_mutex);
}

void shared_read_cmd(cmd_output_t *cmd, float motors[4])
{
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    *cmd = s_cmd;
    memcpy(motors, s_motors, sizeof(s_motors));
    xSemaphoreGive(s_state_mutex);
}

/* ── App entry ─────────────────────────────────────────── */

void app_main(void)
{
    ESP_LOGI(TAG, "Drone Flight Controller starting...");

    /* NVS — required by Wi-Fi */
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
        ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    /* Mutex */
    s_state_mutex = xSemaphoreCreateMutex();
    configASSERT(s_state_mutex);

    /* Init subsystems */
    wifi_manager_init(WIFI_SSID, WIFI_PASS, WIFI_MAX_RETRY);
    motor_output_init();
    status_led_init(STATUS_LED_PIN);

    /* Start tasks */
    wifi_manager_start();               /* prio 2, core 0 */
    udp_comm_start();                   /* prio 3, core 0 — always runs for TX */

#if USE_REAL_SENSORS
    /* Initialise I2C bus for MPU6050 + BMP280 */
    i2c_config_t i2c_conf = {
        .mode             = I2C_MODE_MASTER,
        .sda_io_num       = I2C_SDA_PIN,
        .scl_io_num       = I2C_SCL_PIN,
        .sda_pullup_en    = GPIO_PULLUP_ENABLE,
        .scl_pullup_en    = GPIO_PULLUP_ENABLE,
        .master.clk_speed = I2C_FREQ_HZ,
    };
    ESP_ERROR_CHECK(i2c_param_config(I2C_MASTER_NUM, &i2c_conf));
    ESP_ERROR_CHECK(i2c_driver_install(I2C_MASTER_NUM, i2c_conf.mode, 0, 0, 0));
    ESP_LOGI(TAG, "I2C bus initialised (SDA=%d SCL=%d %dHz)", I2C_SDA_PIN, I2C_SCL_PIN, I2C_FREQ_HZ);

    sensor_fusion_start();              /* prio 4, core 0 — replaces simulator telemetry */
#endif

    attitude_controller_start();        /* prio 5, core 1 */
    status_led_start();                 /* prio 1, any    */

    ESP_LOGI(TAG, "All tasks started (sensors=%d, binary=%d).", USE_REAL_SENSORS, USE_BINARY_PROTOCOL);
}
