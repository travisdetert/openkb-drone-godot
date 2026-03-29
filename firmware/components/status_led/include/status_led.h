#pragma once

#include <stdint.h>

/**
 * Initialise the status LED GPIO.
 */
void status_led_init(int gpio_num);

/**
 * Start the status LED task (priority 1).
 *
 * Blink patterns:
 *   Slow (1Hz)   = no Wi-Fi connection
 *   Fast (5Hz)   = Wi-Fi ok, no telemetry data
 *   Heartbeat    = connected and receiving data
 */
void status_led_start(void);
