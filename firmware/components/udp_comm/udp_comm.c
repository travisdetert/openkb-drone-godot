#include "udp_comm.h"

#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_timer.h"

#include "wifi_manager.h"

/* Import config from main app */
#include "app_config.h"

#if USE_BINARY_PROTOCOL
#include "binary_protocol.h"
#else
#include "cJSON.h"
#endif

static const char *TAG = "udp";

/* ── Packet parsing ───────────────────────────────────── */

#if USE_BINARY_PROTOCOL

static bool parse_telemetry(const uint8_t *buf, int len, imu_state_t *out)
{
    proto_packet_t pkt;
    if (proto_decode(buf, (size_t)len, &pkt) < 0) return false;

    if (pkt.type == PKT_EULER_STATE) {
        bool active;
        if (!proto_decode_euler_state(&pkt,
                &out->pitch_deg, &out->yaw_deg, &out->roll_deg,
                &out->alt, &out->vx, &out->vy, &out->vz,
                &out->hdg, &out->spd, &active))
            return false;
        out->active = active;
    } else if (pkt.type == PKT_FULL_STATE) {
        if (!proto_decode_full_state(&pkt,
                &out->pitch_deg, &out->yaw_deg, &out->roll_deg,
                &out->alt, &out->vx, &out->vy, &out->vz,
                &out->hdg, &out->spd))
            return false;
        out->active = true; /* FULL_STATE has no active field */
    } else {
        return false;
    }

    out->timestamp_us = esp_timer_get_time();
    return true;
}

static int format_command(const cmd_output_t *cmd, uint8_t *buf, size_t len)
{
    return proto_encode_control_output(cmd->throttle, cmd->pitch, cmd->roll, cmd->yaw,
                                       buf, len);
}

#else /* JSON mode */

static bool parse_telemetry(const char *json, int len, imu_state_t *out)
{
    (void)len;
    cJSON *root = cJSON_Parse(json);
    if (!root) return false;

    cJSON *att = cJSON_GetObjectItem(root, "att");
    cJSON *pos = cJSON_GetObjectItem(root, "pos");
    cJSON *vel = cJSON_GetObjectItem(root, "vel");

    if (!att || cJSON_GetArraySize(att) < 3 ||
        !pos || cJSON_GetArraySize(pos) < 3 ||
        !vel || cJSON_GetArraySize(vel) < 3) {
        cJSON_Delete(root);
        return false;
    }

    out->pitch_deg = (float)cJSON_GetArrayItem(att, 0)->valuedouble;
    out->yaw_deg   = (float)cJSON_GetArrayItem(att, 1)->valuedouble;
    out->roll_deg  = (float)cJSON_GetArrayItem(att, 2)->valuedouble;

    out->alt = (float)cJSON_GetArrayItem(pos, 1)->valuedouble;
    out->vx  = (float)cJSON_GetArrayItem(vel, 0)->valuedouble;
    out->vy  = (float)cJSON_GetArrayItem(vel, 1)->valuedouble;
    out->vz  = (float)cJSON_GetArrayItem(vel, 2)->valuedouble;

    cJSON *hdg = cJSON_GetObjectItem(root, "hdg");
    if (hdg) out->hdg = (float)hdg->valuedouble;

    cJSON *spd = cJSON_GetObjectItem(root, "spd");
    if (spd) out->spd = (float)spd->valuedouble;

    cJSON *active = cJSON_GetObjectItem(root, "active");
    if (active) out->active = cJSON_IsTrue(active);

    out->timestamp_us = esp_timer_get_time();

    cJSON_Delete(root);
    return true;
}

static int format_command(const cmd_output_t *cmd, char *buf, size_t len)
{
    return snprintf(buf, len,
        "{\"throttle\":%.4f,\"pitch\":%.4f,\"roll\":%.4f,\"yaw\":%.4f}",
        cmd->throttle, cmd->pitch, cmd->roll, cmd->yaw);
}

#endif /* USE_BINARY_PROTOCOL */

/* ── Telemetry task ────────────────────────────────────── */

static void telemetry_task(void *arg)
{
    /* Wait for Wi-Fi */
    while (!wifi_manager_is_connected()) {
        vTaskDelay(pdMS_TO_TICKS(500));
    }
    ESP_LOGI(TAG, "Wi-Fi connected, starting UDP comm");

    /* RX socket — bind to telemetry port */
    int rx_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (rx_sock < 0) {
        ESP_LOGE(TAG, "Failed to create RX socket");
        vTaskDelete(NULL);
        return;
    }

    /* Allow broadcast receive */
    int broadcast = 1;
    setsockopt(rx_sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));

    struct sockaddr_in rx_addr = {
        .sin_family      = AF_INET,
        .sin_port        = htons(UDP_TELEMETRY_PORT),
        .sin_addr.s_addr = htonl(INADDR_ANY),
    };
    if (bind(rx_sock, (struct sockaddr *)&rx_addr, sizeof(rx_addr)) < 0) {
        ESP_LOGE(TAG, "Failed to bind RX socket");
        close(rx_sock);
        vTaskDelete(NULL);
        return;
    }

    /* Non-blocking with short timeout for polling */
    struct timeval tv = { .tv_sec = 0, .tv_usec = 20000 }; /* 20ms */
    setsockopt(rx_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    /* TX socket */
    int tx_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (tx_sock < 0) {
        ESP_LOGE(TAG, "Failed to create TX socket");
        close(rx_sock);
        vTaskDelete(NULL);
        return;
    }

    setsockopt(tx_sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));

    struct sockaddr_in tx_addr = {
        .sin_family      = AF_INET,
        .sin_port        = htons(UDP_COMMAND_PORT),
    };
    inet_pton(AF_INET, GODOT_HOST_IP, &tx_addr.sin_addr);

    uint8_t rx_buf[256];
    uint8_t tx_buf[128];
    TickType_t last_tx = 0;
    const TickType_t tx_interval = pdMS_TO_TICKS(1000 / TELEMETRY_POLL_HZ);

    ESP_LOGI(TAG, "UDP sockets ready — RX:%d TX:%d (binary=%d)",
             UDP_TELEMETRY_PORT, UDP_COMMAND_PORT, USE_BINARY_PROTOCOL);

    while (1) {
        /* ── RX: drain all available packets ──────────── */
        int len;
        struct sockaddr_in src_addr;
        socklen_t src_len = sizeof(src_addr);

        while ((len = recvfrom(rx_sock, rx_buf, sizeof(rx_buf) - 1, 0,
                               (struct sockaddr *)&src_addr, &src_len)) > 0) {

            imu_state_t imu;
#if USE_BINARY_PROTOCOL
            if (parse_telemetry(rx_buf, len, &imu)) {
#else
            rx_buf[len] = '\0';
            if (parse_telemetry((const char *)rx_buf, len, &imu)) {
#endif
                shared_write_imu(&imu);

                /* Update TX destination to sender's IP (auto-discover host) */
                tx_addr.sin_addr = src_addr.sin_addr;
            }
        }

        /* ── TX: send commands at 50Hz ────────────────── */
        TickType_t now = xTaskGetTickCount();
        if ((now - last_tx) >= tx_interval) {
            last_tx = now;

            cmd_output_t cmd;
            float motors[4];
            shared_read_cmd(&cmd, motors);

            int n = format_command(&cmd, tx_buf, sizeof(tx_buf));
            if (n > 0) {
                sendto(tx_sock, tx_buf, n, 0,
                       (struct sockaddr *)&tx_addr, sizeof(tx_addr));
            }
        }

        vTaskDelay(pdMS_TO_TICKS(1));
    }
}

void udp_comm_start(void)
{
    xTaskCreatePinnedToCore(telemetry_task, "telemetry", 4096, NULL, 3, NULL, 0);
}
