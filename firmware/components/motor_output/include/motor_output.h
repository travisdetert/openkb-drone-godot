#pragma once

/**
 * Initialise 4 LEDC PWM channels for motor ESC output.
 */
void motor_output_init(void);

/**
 * Set motor outputs (normalised 0..1).
 * Maps to 1000–2000µs pulse width on 50Hz PWM.
 */
void motor_output_set(const float values[4]);
