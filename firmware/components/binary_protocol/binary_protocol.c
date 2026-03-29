#include "binary_protocol.h"

#include <string.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* ── Helpers for little-endian float read/write ──────── */

static void write_f32_le(uint8_t *dst, float val)
{
    uint8_t *src = (uint8_t *)&val;
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    memcpy(dst, src, 4);
#else
    dst[0] = src[3]; dst[1] = src[2]; dst[2] = src[1]; dst[3] = src[0];
#endif
}

static float read_f32_le(const uint8_t *src)
{
    float val;
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    memcpy(&val, src, 4);
#else
    uint8_t tmp[4] = { src[3], src[2], src[1], src[0] };
    memcpy(&val, tmp, 4);
#endif
    return val;
}

/* ── Checksum ─────────────────────────────────────────── */

uint8_t proto_checksum(const uint8_t *data, size_t len)
{
    uint8_t cs = 0;
    for (size_t i = 0; i < len; i++) {
        cs ^= data[i];
    }
    return cs;
}

/* ── Encode ───────────────────────────────────────────── */

int proto_encode(const proto_packet_t *pkt, uint8_t *buf, size_t buf_len)
{
    size_t frame_len = PROTO_OVERHEAD + pkt->length;
    if (buf_len < frame_len) return -1;

    buf[0] = PROTO_SYNC1;
    buf[1] = PROTO_SYNC2;
    buf[2] = pkt->length;
    buf[3] = pkt->type;
    if (pkt->length > 0) {
        memcpy(&buf[4], pkt->payload, pkt->length);
    }

    /* XOR checksum: bytes [2] through [3 + length - 1] = length, type, payload */
    buf[4 + pkt->length] = proto_checksum(&buf[2], 2 + pkt->length);

    return (int)frame_len;
}

/* ── Decode ───────────────────────────────────────────── */

int proto_decode(const uint8_t *buf, size_t buf_len, proto_packet_t *out)
{
    if (buf_len < PROTO_OVERHEAD) return -1;
    if (buf[0] != PROTO_SYNC1 || buf[1] != PROTO_SYNC2) return -1;

    uint8_t length = buf[2];
    size_t frame_len = PROTO_OVERHEAD + length;
    if (buf_len < frame_len) return -1;
    if (length > PROTO_MAX_PAYLOAD) return -1;

    /* Verify checksum */
    uint8_t expected = proto_checksum(&buf[2], 2 + length);
    if (expected != buf[4 + length]) return -1;

    out->type   = buf[3];
    out->length = length;
    if (length > 0) {
        memcpy(out->payload, &buf[4], length);
    }

    return (int)frame_len;
}

/* ── CONTROL_OUTPUT encoder ───────────────────────────── */

int proto_encode_control_output(float throttle, float pitch, float roll, float yaw,
                                uint8_t *buf, size_t buf_len)
{
    proto_packet_t pkt;
    pkt.type   = PKT_CONTROL_OUTPUT;
    pkt.length = 16; /* 4 x float32 */

    write_f32_le(&pkt.payload[0],  throttle);
    write_f32_le(&pkt.payload[4],  pitch);
    write_f32_le(&pkt.payload[8],  roll);
    write_f32_le(&pkt.payload[12], yaw);

    return proto_encode(&pkt, buf, buf_len);
}

/* ── FULL_STATE decoder (quaternion → Euler) ──────────── */

bool proto_decode_full_state(const proto_packet_t *pkt,
                             float *pitch_deg, float *yaw_deg, float *roll_deg,
                             float *alt, float *vx, float *vy, float *vz,
                             float *hdg, float *spd)
{
    if (pkt->type != PKT_FULL_STATE) return false;
    /* Minimum payload: pos(12) + vel(12) + quat(16) = 40 bytes */
    if (pkt->length < 40) return false;

    const uint8_t *p = pkt->payload;

    /* Position: [x, y, z] */
    float px = read_f32_le(&p[0]);
    float py = read_f32_le(&p[4]);
    float pz = read_f32_le(&p[8]);
    (void)px; (void)pz; /* only altitude (y) used for now */
    *alt = py;

    /* Velocity: [vx, vy, vz] */
    *vx = read_f32_le(&p[12]);
    *vy = read_f32_le(&p[16]);
    *vz = read_f32_le(&p[20]);

    /* Quaternion: [w, x, y, z] */
    float qw = read_f32_le(&p[24]);
    float qx = read_f32_le(&p[28]);
    float qy = read_f32_le(&p[32]);
    float qz = read_f32_le(&p[36]);

    /* Quaternion → Euler (aerospace convention) */
    float sinr_cosp = 2.0f * (qw * qx + qy * qz);
    float cosr_cosp = 1.0f - 2.0f * (qx * qx + qy * qy);
    *roll_deg = atan2f(sinr_cosp, cosr_cosp) * (180.0f / (float)M_PI);

    float sinp = 2.0f * (qw * qy - qz * qx);
    if (fabsf(sinp) >= 1.0f)
        *pitch_deg = copysignf(90.0f, sinp);
    else
        *pitch_deg = asinf(sinp) * (180.0f / (float)M_PI);

    float siny_cosp = 2.0f * (qw * qz + qx * qy);
    float cosy_cosp = 1.0f - 2.0f * (qy * qy + qz * qz);
    *yaw_deg = atan2f(siny_cosp, cosy_cosp) * (180.0f / (float)M_PI);

    /* Derived: heading = yaw (0-360), speed = horizontal magnitude */
    *hdg = *yaw_deg;
    if (*hdg < 0.0f) *hdg += 360.0f;

    *spd = sqrtf((*vx) * (*vx) + (*vz) * (*vz));

    return true;
}

/* ── EULER_STATE encoder ──────────────────────────────── */

int proto_encode_euler_state(float pitch_deg, float yaw_deg, float roll_deg,
                             float alt_val, float vx_val, float vy_val, float vz_val,
                             float hdg_val, float spd_val, bool active,
                             uint8_t *buf, size_t buf_len)
{
    proto_packet_t pkt;
    pkt.type   = PKT_EULER_STATE;
    pkt.length = 37; /* 9 x float32 + 1 x uint8 */

    write_f32_le(&pkt.payload[0],  pitch_deg);
    write_f32_le(&pkt.payload[4],  yaw_deg);
    write_f32_le(&pkt.payload[8],  roll_deg);
    write_f32_le(&pkt.payload[12], alt_val);
    write_f32_le(&pkt.payload[16], vx_val);
    write_f32_le(&pkt.payload[20], vy_val);
    write_f32_le(&pkt.payload[24], vz_val);
    write_f32_le(&pkt.payload[28], hdg_val);
    write_f32_le(&pkt.payload[32], spd_val);
    pkt.payload[36] = active ? 1 : 0;

    return proto_encode(&pkt, buf, buf_len);
}

/* ── EULER_STATE decoder ──────────────────────────────── */

bool proto_decode_euler_state(const proto_packet_t *pkt,
                              float *pitch_deg, float *yaw_deg, float *roll_deg,
                              float *alt_val, float *vx_val, float *vy_val, float *vz_val,
                              float *hdg_val, float *spd_val, bool *active)
{
    if (pkt->type != PKT_EULER_STATE) return false;
    if (pkt->length < 37) return false;

    const uint8_t *p = pkt->payload;

    *pitch_deg = read_f32_le(&p[0]);
    *yaw_deg   = read_f32_le(&p[4]);
    *roll_deg  = read_f32_le(&p[8]);
    *alt_val   = read_f32_le(&p[12]);
    *vx_val    = read_f32_le(&p[16]);
    *vy_val    = read_f32_le(&p[20]);
    *vz_val    = read_f32_le(&p[24]);
    *hdg_val   = read_f32_le(&p[28]);
    *spd_val   = read_f32_le(&p[32]);
    *active    = (p[36] != 0);

    return true;
}
