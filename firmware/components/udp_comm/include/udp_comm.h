#pragma once

#include <stdint.h>
#include <stdbool.h>

/**
 * IMU state parsed from Godot telemetry JSON.
 * Written by telemetry_task, read by control_task.
 */
typedef struct {
    float pitch_deg;     /* att[0] */
    float yaw_deg;       /* att[1] */
    float roll_deg;      /* att[2] */
    float alt;           /* pos[1] */
    float vx, vy, vz;   /* vel[]  */
    float hdg;           /* heading */
    float spd;           /* horizontal speed */
    bool  active;
    int64_t timestamp_us;
} imu_state_t;

/**
 * Control output from PID, sent back to Godot.
 */
typedef struct {
    float throttle;   /* -1..1 */
    float pitch;      /* -1..1 */
    float roll;       /* -1..1 */
    float yaw;        /* -1..1 */
} cmd_output_t;

/* Shared state accessors (implemented in main.c) */
extern void shared_write_imu(const imu_state_t *imu);
extern void shared_read_imu(imu_state_t *out, int64_t *age_us);
extern void shared_write_cmd(const cmd_output_t *cmd, const float motors[4]);
extern void shared_read_cmd(cmd_output_t *cmd, float motors[4]);

/**
 * Start the telemetry task (priority 3, core 0).
 * RX: parse Godot JSON on UDP_TELEMETRY_PORT → imu_state
 * TX: send cmd_output JSON to Godot on UDP_COMMAND_PORT at 50Hz
 */
void udp_comm_start(void);
