/**
 * Command packet format — maps to future ESP32 serial/UDP protocol.
 *
 * Packet structure (binary):
 *   [0xAA] [0x55] [length] [type] [payload...] [checksum]
 *
 * Sync bytes: 0xAA 0x55
 * Length: payload byte count (excluding sync, length, type, checksum)
 * Type: command type enum
 * Checksum: XOR of all bytes after sync
 */

export const SYNC_BYTE_1 = 0xAA
export const SYNC_BYTE_2 = 0x55

export enum CommandType {
  /** Motor commands: N * uint16 RPM values */
  MOTOR_COMMAND = 0x01,
  /** Arm/disarm: 1 byte (0 = disarm, 1 = arm) */
  ARM_DISARM = 0x02,
  /** Configuration update: variable length */
  CONFIG_UPDATE = 0x03,
  /** Control output: throttle/pitch/roll/yaw as 4 * float32 */
  CONTROL_OUTPUT = 0x04,
  /** Heartbeat / keepalive */
  HEARTBEAT = 0x10,
}

export interface MotorCommandPacket {
  type: CommandType.MOTOR_COMMAND
  /** Per-motor RPM values */
  rpms: number[]
}

export interface ArmDisarmPacket {
  type: CommandType.ARM_DISARM
  armed: boolean
}

export interface ConfigUpdatePacket {
  type: CommandType.CONFIG_UPDATE
  motorCount: number
  bladesPerMotor: number
  mass: number // float32
  armLength: number // float32
}

export interface ControlOutputPacket {
  type: CommandType.CONTROL_OUTPUT
  throttle: number // float32
  pitch: number // float32
  roll: number // float32
  yaw: number // float32
}

export type CommandPacket = MotorCommandPacket | ArmDisarmPacket | ConfigUpdatePacket | ControlOutputPacket

/**
 * Encode a command packet to a binary buffer.
 */
export function encodeCommand(packet: CommandPacket): Uint8Array {
  let payload: Uint8Array

  switch (packet.type) {
    case CommandType.MOTOR_COMMAND: {
      payload = new Uint8Array(packet.rpms.length * 2)
      const view = new DataView(payload.buffer)
      for (let i = 0; i < packet.rpms.length; i++) {
        view.setUint16(i * 2, Math.round(packet.rpms[i]), true) // little-endian
      }
      break
    }
    case CommandType.ARM_DISARM: {
      payload = new Uint8Array([packet.armed ? 1 : 0])
      break
    }
    case CommandType.CONFIG_UPDATE: {
      payload = new Uint8Array(10) // 1 + 1 + 4 + 4
      const view = new DataView(payload.buffer)
      payload[0] = packet.motorCount
      payload[1] = packet.bladesPerMotor
      view.setFloat32(2, packet.mass, true)
      view.setFloat32(6, packet.armLength, true)
      break
    }
    case CommandType.CONTROL_OUTPUT: {
      payload = new Uint8Array(16) // 4 * float32
      const view = new DataView(payload.buffer)
      view.setFloat32(0, packet.throttle, true)
      view.setFloat32(4, packet.pitch, true)
      view.setFloat32(8, packet.roll, true)
      view.setFloat32(12, packet.yaw, true)
      break
    }
  }

  const length = payload.length
  const buffer = new Uint8Array(4 + length + 1) // sync(2) + length(1) + type(1) + payload + checksum(1)
  buffer[0] = SYNC_BYTE_1
  buffer[1] = SYNC_BYTE_2
  buffer[2] = length
  buffer[3] = packet.type

  buffer.set(payload, 4)

  // XOR checksum of length + type + payload
  let checksum = buffer[2]
  for (let i = 3; i < 4 + length; i++) {
    checksum ^= buffer[i]
  }
  buffer[4 + length] = checksum

  return buffer
}

/**
 * Decode a command packet from a binary buffer.
 * Returns null if invalid.
 */
export function decodeCommand(buffer: Uint8Array): CommandPacket | null {
  if (buffer.length < 5) return null
  if (buffer[0] !== SYNC_BYTE_1 || buffer[1] !== SYNC_BYTE_2) return null

  const length = buffer[2]
  const type = buffer[3] as CommandType

  if (buffer.length < 4 + length + 1) return null

  // Verify checksum
  let checksum = buffer[2]
  for (let i = 3; i < 4 + length; i++) {
    checksum ^= buffer[i]
  }
  if (checksum !== buffer[4 + length]) return null

  const payload = buffer.slice(4, 4 + length)

  switch (type) {
    case CommandType.MOTOR_COMMAND: {
      const view = new DataView(payload.buffer, payload.byteOffset, payload.byteLength)
      const rpms: number[] = []
      for (let i = 0; i < payload.length / 2; i++) {
        rpms.push(view.getUint16(i * 2, true))
      }
      return { type, rpms }
    }
    case CommandType.ARM_DISARM:
      return { type, armed: payload[0] === 1 }
    case CommandType.CONFIG_UPDATE: {
      const view = new DataView(payload.buffer, payload.byteOffset, payload.byteLength)
      return {
        type,
        motorCount: payload[0],
        bladesPerMotor: payload[1],
        mass: view.getFloat32(2, true),
        armLength: view.getFloat32(6, true)
      }
    }
    case CommandType.CONTROL_OUTPUT: {
      const view = new DataView(payload.buffer, payload.byteOffset, payload.byteLength)
      return {
        type,
        throttle: view.getFloat32(0, true),
        pitch: view.getFloat32(4, true),
        roll: view.getFloat32(8, true),
        yaw: view.getFloat32(12, true)
      }
    }
    default:
      return null
  }
}
