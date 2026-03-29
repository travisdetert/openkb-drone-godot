#include "pid_controller.h"

static float clampf(float val, float lo, float hi)
{
    if (val < lo) return lo;
    if (val > hi) return hi;
    return val;
}

void pid_init(pid_t *pid, float kp, float ki, float kd,
              float out_min, float out_max, float integral_limit)
{
    pid->kp = kp;
    pid->ki = ki;
    pid->kd = kd;
    pid->out_min = out_min;
    pid->out_max = out_max;
    pid->integral_limit = integral_limit;
    pid->integral = 0.0f;
    pid->prev_error = 0.0f;
    pid->initialized = 0;
}

void pid_reset(pid_t *pid)
{
    pid->integral = 0.0f;
    pid->prev_error = 0.0f;
    pid->initialized = 0;
}

float pid_update(pid_t *pid, float setpoint, float measured, float dt)
{
    float error = setpoint - measured;

    /* Integral with anti-windup clamping */
    pid->integral += error * dt;
    pid->integral = clampf(pid->integral, -pid->integral_limit, pid->integral_limit);

    /* Derivative (skip on first call) */
    float derivative = 0.0f;
    if (pid->initialized) {
        derivative = (error - pid->prev_error) / dt;
    }
    pid->prev_error = error;
    pid->initialized = 1;

    /* PID output */
    float output = pid->kp * error
                 + pid->ki * pid->integral
                 + pid->kd * derivative;

    return clampf(output, pid->out_min, pid->out_max);
}
