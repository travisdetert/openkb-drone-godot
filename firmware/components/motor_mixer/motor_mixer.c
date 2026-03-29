#include "motor_mixer.h"

static float clampf(float val, float lo, float hi)
{
    if (val < lo) return lo;
    if (val > hi) return hi;
    return val;
}

void motor_mixer_compute(float throttle, float roll, float pitch, float yaw,
                         float motors_out[4])
{
    /*
     * Quad-X mixing matrix (matching drone_config.gd create_quad):
     *
     * Motor 0: Front-Right CW   = T - Roll - Pitch - Yaw
     * Motor 1: Front-Left  CCW  = T + Roll - Pitch + Yaw
     * Motor 2: Rear-Left   CW   = T + Roll + Pitch - Yaw
     * Motor 3: Rear-Right  CCW  = T - Roll + Pitch + Yaw
     */
    motors_out[0] = throttle - roll - pitch - yaw;
    motors_out[1] = throttle + roll - pitch + yaw;
    motors_out[2] = throttle + roll + pitch - yaw;
    motors_out[3] = throttle - roll + pitch + yaw;

    /* Clamp to [0, 1] */
    for (int i = 0; i < 4; i++) {
        motors_out[i] = clampf(motors_out[i], 0.0f, 1.0f);
    }
}
