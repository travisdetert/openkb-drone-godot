#include "motor_output.h"

#include "driver/ledc.h"
#include "esp_log.h"

#include "app_config.h"

static const char *TAG = "pwm";

static const int motor_pins[4] = {
    MOTOR_PIN_0, MOTOR_PIN_1, MOTOR_PIN_2, MOTOR_PIN_3
};

/*
 * ESC PWM: 50 Hz (20ms period), 1000µs = idle, 2000µs = full throttle.
 * With 16-bit resolution, max duty = 65535.
 * 1ms / 20ms * 65535 = 3277 (idle)
 * 2ms / 20ms * 65535 = 6554 (full)
 */
#define DUTY_MIN  3277
#define DUTY_MAX  6554

static float clampf(float v, float lo, float hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

void motor_output_init(void)
{
    /* Timer config — shared by all 4 channels */
    ledc_timer_config_t timer_conf = {
        .speed_mode      = LEDC_LOW_SPEED_MODE,
        .duty_resolution = MOTOR_PWM_RES_BITS,
        .timer_num       = LEDC_TIMER_0,
        .freq_hz         = MOTOR_PWM_FREQ_HZ,
        .clk_cfg         = LEDC_AUTO_CLK,
    };
    ESP_ERROR_CHECK(ledc_timer_config(&timer_conf));

    /* Channel config per motor */
    for (int i = 0; i < 4; i++) {
        ledc_channel_config_t ch = {
            .speed_mode = LEDC_LOW_SPEED_MODE,
            .channel    = (ledc_channel_t)i,
            .timer_sel  = LEDC_TIMER_0,
            .intr_type  = LEDC_INTR_DISABLE,
            .gpio_num   = motor_pins[i],
            .duty       = DUTY_MIN,
            .hpoint     = 0,
        };
        ESP_ERROR_CHECK(ledc_channel_config(&ch));
    }

    ESP_LOGI(TAG, "Motor PWM init — pins %d,%d,%d,%d @ %dHz %d-bit",
             motor_pins[0], motor_pins[1], motor_pins[2], motor_pins[3],
             MOTOR_PWM_FREQ_HZ, MOTOR_PWM_RES_BITS);
}

void motor_output_set(const float values[4])
{
    for (int i = 0; i < 4; i++) {
        float v = clampf(values[i], 0.0f, 1.0f);
        uint32_t duty = DUTY_MIN + (uint32_t)(v * (DUTY_MAX - DUTY_MIN));
        ledc_set_duty(LEDC_LOW_SPEED_MODE, (ledc_channel_t)i, duty);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, (ledc_channel_t)i);
    }
}
