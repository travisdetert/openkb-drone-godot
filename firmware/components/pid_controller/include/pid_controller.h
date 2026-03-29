#pragma once

/**
 * Generic PID controller with integral anti-windup.
 */
typedef struct {
    float kp, ki, kd;
    float out_min, out_max;
    float integral_limit;

    /* Internal state */
    float integral;
    float prev_error;
    int   initialized;
} pid_t;

/**
 * Initialise a PID controller.
 */
void pid_init(pid_t *pid, float kp, float ki, float kd,
              float out_min, float out_max, float integral_limit);

/**
 * Reset integrator and derivative state.
 */
void pid_reset(pid_t *pid);

/**
 * Compute one PID step.
 * @param setpoint  Desired value
 * @param measured  Current measured value
 * @param dt        Time step in seconds
 * @return          Clamped output
 */
float pid_update(pid_t *pid, float setpoint, float measured, float dt);
