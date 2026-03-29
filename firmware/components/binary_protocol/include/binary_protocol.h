#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* ── Framing constants ────────────────────────────────── */
#define PROTO_SYNC1         0xAA
#define PROTO_SYNC2         0x55
#define PROTO_MAX_PAYLOAD   128
#define PROTO_OVERHEAD      5   /* sync(2) + length(1) + type(1) + checksum(1) */

/* ── Command types (dashboard/controller → drone) ────── */
#define PKT_MOTOR_COMMAND   0x01
#define PKT_ARM_DISARM      0x02
#define PKT_CONFIG_UPDATE   0x03
#define PKT_CONTROL_OUTPUT  0x04  /* throttle/pitch/roll/yaw as 4 x float32 */
#define PKT_HEARTBEAT       0x10

/* ── Telemetry types (drone/simulator → controller) ──── */
#define PKT_FULL_STATE      0x80  /* pos(3f) vel(3f) quat(4f) rpms(N*u16) */
#define PKT_IMU_DATA        0x81  /* accel(3f) gyro(3f) */
#define PKT_BATTERY         0x82  /* voltage(f32) current(f32) percent(u8) */
#define PKT_EULER_STATE     0x83  /* Euler-based state matching imu_state_t */

/* ── Generic packet ───────────────────────────────────── */
typedef struct {
    uint8_t type;
    uint8_t length;                       /* payload byte count */
    uint8_t payload[PROTO_MAX_PAYLOAD];
} proto_packet_t;

/* ── Forward-declared shared types (from udp_comm.h) ──── */
struct imu_state;
struct cmd_output;

/**
 * Compute XOR checksum over `len` bytes starting at `data`.
 */
uint8_t proto_checksum(const uint8_t *data, size_t len);

/**
 * Encode a generic packet into `buf`.
 * @return total frame length on success, -1 on error (buf too small).
 */
int proto_encode(const proto_packet_t *pkt, uint8_t *buf, size_t buf_len);

/**
 * Decode one packet from `buf`.
 * @return bytes consumed on success, -1 on error (bad sync/checksum/length).
 */
int proto_decode(const uint8_t *buf, size_t buf_len, proto_packet_t *out);

/**
 * Convenience: encode a CONTROL_OUTPUT packet (4 x float32, 16 bytes payload).
 * @return total frame length on success, -1 on error.
 */
int proto_encode_control_output(float throttle, float pitch, float roll, float yaw,
                                uint8_t *buf, size_t buf_len);

/**
 * Convenience: decode a FULL_STATE (0x80) telemetry packet.
 * Converts quaternion to Euler angles and populates imu fields.
 * @return true on success.
 */
bool proto_decode_full_state(const proto_packet_t *pkt,
                             float *pitch_deg, float *yaw_deg, float *roll_deg,
                             float *alt, float *vx, float *vy, float *vz,
                             float *hdg, float *spd);

/**
 * Convenience: encode an EULER_STATE (0x83) telemetry packet.
 * Layout: pitch(f32) yaw(f32) roll(f32) alt(f32)
 *         vx(f32) vy(f32) vz(f32) hdg(f32) spd(f32) active(u8)
 * Total payload: 37 bytes.
 * @return total frame length on success, -1 on error.
 */
int proto_encode_euler_state(float pitch_deg, float yaw_deg, float roll_deg,
                             float alt, float vx, float vy, float vz,
                             float hdg, float spd, bool active,
                             uint8_t *buf, size_t buf_len);

/**
 * Convenience: decode an EULER_STATE (0x83) telemetry packet.
 * @return true on success.
 */
bool proto_decode_euler_state(const proto_packet_t *pkt,
                              float *pitch_deg, float *yaw_deg, float *roll_deg,
                              float *alt, float *vx, float *vy, float *vz,
                              float *hdg, float *spd, bool *active);
