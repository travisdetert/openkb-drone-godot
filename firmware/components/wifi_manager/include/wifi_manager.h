#pragma once

#include <stdbool.h>

/**
 * Initialise Wi-Fi subsystem in STA mode.
 * Does NOT block — call wifi_manager_start() to launch the event task.
 */
void wifi_manager_init(const char *ssid, const char *password, int max_retry);

/**
 * Start the Wi-Fi connection task (priority 2, core 0).
 */
void wifi_manager_start(void);

/**
 * Returns true when an IP address has been obtained.
 */
bool wifi_manager_is_connected(void);
