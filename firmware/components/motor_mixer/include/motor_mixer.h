#pragma once

/**
 * Quad-X motor mixing.
 *
 * Inputs are normalised [-1,1] (throttle [0,1]).
 * Outputs are normalised [0,1] per motor.
 *
 * Motor layout (matching drone_config.gd create_quad):
 *   Motor 0: Front-Right CW   → T - R - P - Y
 *   Motor 1: Front-Left  CCW  → T + R - P + Y
 *   Motor 2: Rear-Left   CW   → T + R + P - Y
 *   Motor 3: Rear-Right  CCW  → T - R + P + Y
 */
void motor_mixer_compute(float throttle, float roll, float pitch, float yaw,
                         float motors_out[4]);
