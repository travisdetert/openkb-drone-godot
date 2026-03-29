#include "status_led.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "esp_log.h"

#include "wifi_manager.h"
#include "udp_comm.h"

#include "app_config.h"

static int s_gpio;

void status_led_init(int gpio_num)
{
    s_gpio = gpio_num;
    gpio_reset_pin(gpio_num);
    gpio_set_direction(gpio_num, GPIO_MODE_OUTPUT);
    gpio_set_level(gpio_num, 0);
}

static void status_task(void *arg)
{
    int state = 0;

    while (1) {
        int delay_ms;

        if (!wifi_manager_is_connected()) {
            /* Slow blink — no Wi-Fi */
            delay_ms = 500;
        } else {
            /* Check telemetry age */
            imu_state_t imu;
            int64_t age_us;
            shared_read_imu(&imu, &age_us);

            if (age_us > (int64_t)FAILSAFE_TIMEOUT_MS * 1000) {
                /* Fast blink — Wi-Fi ok but no data */
                delay_ms = 100;
            } else {
                /* Heartbeat — short on, long off */
                state = !state;
                gpio_set_level(s_gpio, state);
                vTaskDelay(pdMS_TO_TICKS(state ? 50 : 950));
                continue;
            }
        }

        state = !state;
        gpio_set_level(s_gpio, state);
        vTaskDelay(pdMS_TO_TICKS(delay_ms));
    }
}

void status_led_start(void)
{
    xTaskCreate(status_task, "status_led", 2048, NULL, 1, NULL);
}
