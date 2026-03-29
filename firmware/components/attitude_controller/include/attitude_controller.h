#pragma once

/**
 * Start the attitude control task (priority 5, core 1, 500 Hz).
 *
 * Runs dual-loop PID:
 *   outer: angle → desired rate
 *   inner: rate → normalised output [-1,1]
 *
 * Feeds motor_mixer, writes LEDC PWM, and publishes cmd_output.
 */
void attitude_controller_start(void);
