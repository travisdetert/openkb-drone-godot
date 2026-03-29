#include "wifi_manager.h"

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"

static const char *TAG = "wifi";

#define WIFI_CONNECTED_BIT  BIT0
#define WIFI_FAIL_BIT       BIT1

static EventGroupHandle_t s_wifi_event_group;
static int  s_max_retry;
static int  s_retry_count;
static bool s_connected;

static char s_ssid[32];
static char s_pass[64];

/* ── Event handler ─────────────────────────────────────── */

static void event_handler(void *arg, esp_event_base_t base,
                          int32_t id, void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        s_connected = false;
        if (s_retry_count < s_max_retry) {
            esp_wifi_connect();
            s_retry_count++;
            ESP_LOGI(TAG, "Reconnecting… attempt %d", s_retry_count);
        } else {
            xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
            ESP_LOGW(TAG, "Max retries reached, will keep trying slowly");
            vTaskDelay(pdMS_TO_TICKS(5000));
            s_retry_count = 0;
            esp_wifi_connect();
        }
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)data;
        ESP_LOGI(TAG, "Connected — IP: " IPSTR, IP2STR(&event->ip_info.ip));
        s_retry_count = 0;
        s_connected = true;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

/* ── Public API ────────────────────────────────────────── */

void wifi_manager_init(const char *ssid, const char *password, int max_retry)
{
    strncpy(s_ssid, ssid, sizeof(s_ssid) - 1);
    strncpy(s_pass, password, sizeof(s_pass) - 1);
    s_max_retry = max_retry;

    s_wifi_event_group = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL, NULL));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL, NULL));

    wifi_config_t wifi_config = {0};
    strncpy((char *)wifi_config.sta.ssid, s_ssid, sizeof(wifi_config.sta.ssid));
    strncpy((char *)wifi_config.sta.password, s_pass, sizeof(wifi_config.sta.password));
    wifi_config.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
}

void wifi_manager_start(void)
{
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_LOGI(TAG, "Wi-Fi STA started, connecting to %s…", s_ssid);
}

bool wifi_manager_is_connected(void)
{
    return s_connected;
}
