# Binary Protocol Specification

The firmware and simulator communicate using a compact binary protocol over UDP. This document is the authoritative reference. TypeScript encoder/decoder implementations are in `protocol/command-spec.ts` and `protocol/telemetry-spec.ts`.

## Transport

| Direction | Port | Content |
|-----------|------|---------|
| Godot/Simulator to Firmware | UDP 4210 | Telemetry state packets |
| Firmware to Godot/Dashboard | UDP 4211 | Control output packets |

Both directions use broadcast addressing (`255.255.255.255`) by default. The firmware auto-discovers the Godot host IP from incoming packets.

## Packet Frame

Every packet follows this structure:

```
┌──────┬──────┬────────┬──────┬───────────┬──────────┐
│ 0xAA │ 0x55 │ Length │ Type │  Payload  │ Checksum │
│  1B  │  1B  │   1B   │  1B  │  0-128B   │    1B    │
└──────┴──────┴────────┴──────┴───────────┴──────────┘
```

| Field | Size | Description |
|-------|------|-------------|
| Sync 1 | 1 byte | Always `0xAA` |
| Sync 2 | 1 byte | Always `0x55` |
| Length | 1 byte | Payload length in bytes (0--128) |
| Type | 1 byte | Packet type identifier |
| Payload | 0--128 bytes | Type-specific data |
| Checksum | 1 byte | XOR of length, type, and all payload bytes |

### Checksum Calculation

```
checksum = length XOR type
for each byte in payload:
    checksum = checksum XOR byte
```

### Maximum Packet Size

With a 128-byte payload, the maximum total packet size is 133 bytes (2 sync + 1 length + 1 type + 128 payload + 1 checksum).

## Command Packets (Firmware RX)

Commands are sent from the simulator or a control station to the firmware.

### MOTOR_COMMAND (0x01)

Direct RPM control for each motor. Used for motor testing and calibration.

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint16 LE | Motor 0 RPM |
| 2 | uint16 LE | Motor 1 RPM |
| 4 | uint16 LE | Motor 2 RPM |
| ... | uint16 LE | Motor N RPM |

Payload length: `motorCount * 2` bytes.

### ARM_DISARM (0x02)

Arms or disarms the flight controller.

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | 0 = disarm, 1 = arm |

Payload length: 1 byte.

### CONFIG_UPDATE (0x03)

Updates drone configuration parameters.

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | Motor count |
| 1 | uint8 | Blades per motor |
| 2 | float32 LE | Mass (kg) |
| 6 | float32 LE | Arm length (m) |

Payload length: 10 bytes.

### CONTROL_OUTPUT (0x04)

Normalized flight control inputs. This is the primary command packet sent at 50 Hz.

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| 0 | float32 LE | Throttle | 0.0 to 1.0 |
| 4 | float32 LE | Pitch | -1.0 to 1.0 |
| 8 | float32 LE | Roll | -1.0 to 1.0 |
| 12 | float32 LE | Yaw | -1.0 to 1.0 |

Payload length: 16 bytes.

### HEARTBEAT (0x10)

Keepalive packet with no payload. Resets the failsafe timeout counter.

Payload length: 0 bytes.

## Telemetry Packets (Firmware TX / Godot TX)

Telemetry packets carry sensor and state data. In simulator mode, Godot sends these to the firmware. In hardware mode, the firmware generates them from real sensors. The dashboard also receives these for display.

### FULL_STATE (0x80)

Complete drone state including position and quaternion orientation.

| Offset | Type | Field |
|--------|------|-------|
| 0 | float32 LE | Position X (m) |
| 4 | float32 LE | Position Y (m) |
| 8 | float32 LE | Position Z (m) |
| 12 | float32 LE | Velocity X (m/s) |
| 16 | float32 LE | Velocity Y (m/s) |
| 20 | float32 LE | Velocity Z (m/s) |
| 24 | float32 LE | Quaternion W |
| 28 | float32 LE | Quaternion X |
| 32 | float32 LE | Quaternion Y |
| 36 | float32 LE | Quaternion Z |
| 40 | uint16 LE | Motor 0 RPM |
| 42 | uint16 LE | Motor 1 RPM |
| ... | uint16 LE | Motor N RPM |

Payload length: `40 + motorCount * 2` bytes.

### IMU_DATA (0x81)

Raw IMU sensor readings.

| Offset | Type | Field |
|--------|------|-------|
| 0 | float32 LE | Accel X (g) |
| 4 | float32 LE | Accel Y (g) |
| 8 | float32 LE | Accel Z (g) |
| 12 | float32 LE | Gyro X (deg/s) |
| 16 | float32 LE | Gyro Y (deg/s) |
| 20 | float32 LE | Gyro Z (deg/s) |

Payload length: 24 bytes.

### BATTERY (0x82)

Battery status.

| Offset | Type | Field |
|--------|------|-------|
| 0 | float32 LE | Voltage (V) |
| 4 | float32 LE | Current (A) |
| 8 | uint8 | Percentage (0--100) |

Payload length: 9 bytes.

### EULER_STATE (0x83)

Attitude and flight data using Euler angles. This is the primary telemetry packet used in simulator mode at 50 Hz.

| Offset | Type | Field |
|--------|------|-------|
| 0 | float32 LE | Pitch (degrees) |
| 4 | float32 LE | Yaw (degrees) |
| 8 | float32 LE | Roll (degrees) |
| 12 | float32 LE | Altitude (m) |
| 16 | float32 LE | Velocity X (m/s) |
| 20 | float32 LE | Velocity Y (m/s) |
| 24 | float32 LE | Velocity Z (m/s) |
| 28 | float32 LE | Heading (degrees) |
| 32 | float32 LE | Horizontal speed (m/s) |
| 36 | uint8 | Active (0 = disarmed, 1 = armed) |

Payload length: 37 bytes.

## Encoding Examples

### TypeScript

Encoding a control output command:

```typescript
import { encodeCommand, CommandType } from './protocol/command-spec';

const packet = encodeCommand({
  type: CommandType.CONTROL_OUTPUT,
  throttle: 0.5,
  pitch: 0.1,
  roll: -0.05,
  yaw: 0.0,
});
// packet is a Uint8Array ready to send over UDP
```

Decoding telemetry:

```typescript
import { decodeTelemetry, TelemetryType } from './protocol/telemetry-spec';

const result = decodeTelemetry(buffer);
if (result.type === TelemetryType.EULER_STATE) {
  console.log(`Pitch: ${result.pitch}, Alt: ${result.altitude}`);
}
```

### C (firmware)

Encoding a control output packet:

```c
#include "binary_protocol.h"

uint8_t buf[BINARY_PROTO_MAX_PACKET];
cmd_output_t cmd = { .throttle = 0.5f, .pitch = 0.1f, .roll = -0.05f, .yaw = 0.0f };
int len = binary_proto_encode_control_output(&cmd, buf, sizeof(buf));
// send buf[0..len-1] over UDP
```

Decoding a telemetry packet:

```c
binary_proto_packet_t pkt;
if (binary_proto_decode(rx_buf, rx_len, &pkt) == 0) {
    if (pkt.type == PKT_EULER_STATE) {
        imu_state_t state;
        binary_proto_decode_euler_state(&pkt, &state);
    }
}
```

## JSON Fallback

When `USE_BINARY_PROTOCOL=0`, the firmware falls back to JSON encoding. The dashboard server (`server.mjs`) auto-detects binary vs JSON by checking if the first byte is `0xAA`.

JSON telemetry format:

```json
{
  "pitch": 2.1,
  "yaw": -0.5,
  "roll": 1.3,
  "altitude": 5.2,
  "vx": 0.1,
  "vy": 0.3,
  "vz": -0.05,
  "heading": 45.0,
  "speed": 3.2,
  "active": true
}
```

## Integration Guide

### Adding a New Command Type

1. Define the type constant in `firmware/components/binary_protocol/include/binary_protocol.h`
2. Add encode/decode functions in `binary_protocol.c`
3. Add the handler in `udp_comm.c` (RX path)
4. Add the TypeScript type in `protocol/command-spec.ts`
5. Update the dashboard if UI is needed

### Adding a New Telemetry Type

1. Define the type constant in `binary_protocol.h`
2. Add encode/decode functions in `binary_protocol.c`
3. Add the sender in `udp_comm.c` (TX path)
4. Add the TypeScript type in `protocol/telemetry-spec.ts`
5. Update `dashboard/server.mjs` to decode and broadcast via WebSocket
