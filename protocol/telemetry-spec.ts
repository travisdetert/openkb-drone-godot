/**
 * Telemetry packet format — maps to future ESP32 serial/UDP protocol.
 *
 * Packet structure (binary):
 *   [0xAA] [0x55] [length] [type] [payload...] [checksum]
 *
 * Same framing as command packets but with telemetry types.
 */

import { SYNC_BYTE_1, SYNC_BYTE_2 } from './command-spec'

export enum TelemetryType {
  /** Full state: position(3f), velocity(3f), quaternion(4f), motorRPMs(N*u16) */
  FULL_STATE = 0x80,
  /** IMU data: accel(3f), gyro(3f) */
  IMU_DATA = 0x81,
  /** Battery: voltage(f32), current(f32), percent(u8) */
  BATTERY = 0x82,
  /** Euler state: pitch/yaw/roll/alt/vx/vy/vz/hdg/spd(9*f32) + active(u8) */
  EULER_STATE = 0x83,
}

export interface FullStateTelemetry {
  type: TelemetryType.FULL_STATE
  position: [number, number, number]
  velocity: [number, number, number]
  quaternion: [number, number, number, number]
  motorRPMs: number[]
}

export interface IMUTelemetry {
  type: TelemetryType.IMU_DATA
  accel: [number, number, number]
  gyro: [number, number, number]
}

export interface BatteryTelemetry {
  type: TelemetryType.BATTERY
  voltage: number
  current: number
  percent: number
}

export interface EulerStateTelemetry {
  type: TelemetryType.EULER_STATE
  pitchDeg: number
  yawDeg: number
  rollDeg: number
  altitude: number
  vx: number
  vy: number
  vz: number
  heading: number
  speed: number
  active: boolean
}

export type TelemetryPacket = FullStateTelemetry | IMUTelemetry | BatteryTelemetry | EulerStateTelemetry

/**
 * Encode a full state telemetry packet.
 */
export function encodeFullState(state: FullStateTelemetry): Uint8Array {
  const motorBytes = state.motorRPMs.length * 2
  const payloadLen = 4 * 3 + 4 * 3 + 4 * 4 + motorBytes // position + velocity + quaternion + motors
  const payload = new Uint8Array(payloadLen)
  const view = new DataView(payload.buffer)

  let offset = 0
  // Position
  for (let i = 0; i < 3; i++) {
    view.setFloat32(offset, state.position[i], true)
    offset += 4
  }
  // Velocity
  for (let i = 0; i < 3; i++) {
    view.setFloat32(offset, state.velocity[i], true)
    offset += 4
  }
  // Quaternion
  for (let i = 0; i < 4; i++) {
    view.setFloat32(offset, state.quaternion[i], true)
    offset += 4
  }
  // Motor RPMs
  for (let i = 0; i < state.motorRPMs.length; i++) {
    view.setUint16(offset, Math.round(state.motorRPMs[i]), true)
    offset += 2
  }

  // Frame it
  const buffer = new Uint8Array(4 + payloadLen + 1)
  buffer[0] = SYNC_BYTE_1
  buffer[1] = SYNC_BYTE_2
  buffer[2] = payloadLen
  buffer[3] = state.type

  buffer.set(payload, 4)

  let checksum = buffer[2]
  for (let i = 3; i < 4 + payloadLen; i++) {
    checksum ^= buffer[i]
  }
  buffer[4 + payloadLen] = checksum

  return buffer
}

/**
 * Encode an Euler state telemetry packet.
 * Payload: 9 * float32 + 1 * uint8 = 37 bytes.
 */
export function encodeEulerState(state: EulerStateTelemetry): Uint8Array {
  const payloadLen = 37
  const payload = new Uint8Array(payloadLen)
  const view = new DataView(payload.buffer)

  view.setFloat32(0, state.pitchDeg, true)
  view.setFloat32(4, state.yawDeg, true)
  view.setFloat32(8, state.rollDeg, true)
  view.setFloat32(12, state.altitude, true)
  view.setFloat32(16, state.vx, true)
  view.setFloat32(20, state.vy, true)
  view.setFloat32(24, state.vz, true)
  view.setFloat32(28, state.heading, true)
  view.setFloat32(32, state.speed, true)
  payload[36] = state.active ? 1 : 0

  const buffer = new Uint8Array(4 + payloadLen + 1)
  buffer[0] = SYNC_BYTE_1
  buffer[1] = SYNC_BYTE_2
  buffer[2] = payloadLen
  buffer[3] = state.type

  buffer.set(payload, 4)

  let checksum = buffer[2]
  for (let i = 3; i < 4 + payloadLen; i++) {
    checksum ^= buffer[i]
  }
  buffer[4 + payloadLen] = checksum

  return buffer
}

/**
 * Decode a telemetry packet from a binary buffer.
 * Returns null if invalid.
 */
export function decodeTelemetry(buffer: Uint8Array): TelemetryPacket | null {
  if (buffer.length < 5) return null
  if (buffer[0] !== SYNC_BYTE_1 || buffer[1] !== SYNC_BYTE_2) return null

  const length = buffer[2]
  const type = buffer[3] as TelemetryType

  if (buffer.length < 4 + length + 1) return null

  let checksum = buffer[2]
  for (let i = 3; i < 4 + length; i++) {
    checksum ^= buffer[i]
  }
  if (checksum !== buffer[4 + length]) return null

  const payload = buffer.slice(4, 4 + length)
  const view = new DataView(payload.buffer, payload.byteOffset, payload.byteLength)

  switch (type) {
    case TelemetryType.EULER_STATE: {
      if (length < 37) return null
      return {
        type,
        pitchDeg: view.getFloat32(0, true),
        yawDeg: view.getFloat32(4, true),
        rollDeg: view.getFloat32(8, true),
        altitude: view.getFloat32(12, true),
        vx: view.getFloat32(16, true),
        vy: view.getFloat32(20, true),
        vz: view.getFloat32(24, true),
        heading: view.getFloat32(28, true),
        speed: view.getFloat32(32, true),
        active: payload[36] !== 0,
      }
    }
    case TelemetryType.FULL_STATE: {
      if (length < 40) return null
      const motorCount = (length - 40) / 2
      const motorRPMs: number[] = []
      for (let i = 0; i < motorCount; i++) {
        motorRPMs.push(view.getUint16(40 + i * 2, true))
      }
      return {
        type,
        position: [view.getFloat32(0, true), view.getFloat32(4, true), view.getFloat32(8, true)],
        velocity: [view.getFloat32(12, true), view.getFloat32(16, true), view.getFloat32(20, true)],
        quaternion: [view.getFloat32(24, true), view.getFloat32(28, true), view.getFloat32(32, true), view.getFloat32(36, true)],
        motorRPMs,
      }
    }
    case TelemetryType.IMU_DATA: {
      if (length < 24) return null
      return {
        type,
        accel: [view.getFloat32(0, true), view.getFloat32(4, true), view.getFloat32(8, true)],
        gyro: [view.getFloat32(12, true), view.getFloat32(16, true), view.getFloat32(20, true)],
      }
    }
    case TelemetryType.BATTERY: {
      if (length < 9) return null
      return {
        type,
        voltage: view.getFloat32(0, true),
        current: view.getFloat32(4, true),
        percent: payload[8],
      }
    }
    default:
      return null
  }
}
