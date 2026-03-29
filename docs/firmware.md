# Firmware Guide

The flight controller firmware runs on an ESP32-WROOM-32, targeting a 250mm quadcopter frame. It is built with ESP-IDF and FreeRTOS, using a modular component architecture.

## Prerequisites

- [ESP-IDF v5.0+](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/)
- USB cable (micro-USB for DevKit V1)
- ESP32 DevKit V1 board (for hardware mode)

## Build and Flash

```bash
# Source the ESP-IDF environment
. ~/esp/esp-idf/export.sh   # adjust path to your installation

cd firmware
idf.py set-target esp32
idf.py build
idf.py flash -p /dev/ttyUSB0    # Linux
idf.py flash -p /dev/cu.SLAB_USBtoUART  # macOS
idf.py monitor -p /dev/ttyUSB0
```

## Configuration

All configuration is in `main/app_config.h`. Key settings:

### WiFi

```c
#define WIFI_SSID "your-ssid"
#define WIFI_PASS "your-password"
```

The ESP32 connects as a WiFi station (client). It auto-discovers the Godot host IP from incoming broadcast packets.

### Operating Mode

```c
#define USE_REAL_SENSORS   0   // 0 = simulator, 1 = hardware
#define USE_BINARY_PROTOCOL 1  // 0 = JSON, 1 = binary
```

**Simulator mode** (`USE_REAL_SENSORS=0`): The firmware receives synthetic telemetry from the Godot simulator over UDP, runs its PID controllers on that data, and sends control output back. No physical sensors needed. Use this mode for algorithm development and PID tuning.

**Hardware mode** (`USE_REAL_SENSORS=1`): The firmware reads the real MPU6050 and BMP280 over I2C, runs the sensor fusion filter, and drives physical motors via PWM. Use this when flying the actual drone.

### Network Ports

```c
#define UDP_TELEMETRY_PORT  4210   // Firmware listens here (telemetry from Godot)
#define UDP_COMMAND_PORT    4211   // Firmware sends here (commands to Godot)
```

### GPIO Pin Map

| GPIO | Function | Component |
|------|----------|-----------|
| 25 | Motor 0 PWM (LEDC Ch 0) | Front-Right ESC, CW |
| 26 | Motor 1 PWM (LEDC Ch 1) | Front-Left ESC, CCW |
| 27 | Motor 2 PWM (LEDC Ch 2) | Rear-Left ESC, CW |
| 14 | Motor 3 PWM (LEDC Ch 3) | Rear-Right ESC, CCW |
| 21 | I2C SDA | MPU6050 + BMP280 |
| 22 | I2C SCL | MPU6050 + BMP280 |
| 2 | Status LED | Onboard LED |

## Architecture

### Task Layout (FreeRTOS)

The firmware uses FreeRTOS with dual-core pinning for deterministic timing:

| Task | Priority | Core | Rate | Purpose |
|------|----------|------|------|---------|
| `wifi_manager` | 2 | 0 | Event-driven | WiFi connection management |
| `udp_comm` | 3 | 0 | 50 Hz TX | UDP receive and telemetry broadcast |
| `sensor_fusion` | 4 | 0 | 500 Hz | Read IMU/baro, fuse attitude (hardware mode only) |
| `attitude_controller` | 5 | 1 | 500 Hz | PID control loop, motor mixing |
| `status_led` | 1 | Any | 2 Hz | LED heartbeat indicator |

Core 0 handles I/O (WiFi, UDP, sensors). Core 1 is dedicated to the time-critical control loop to avoid jitter.

### Data Flow

```
                    ┌──────────────────────────────────┐
                    │            ESP32                  │
                    │                                   │
UDP:4210 ──────────▶│  udp_comm (RX)                   │
(telemetry in)      │       │                          │
                    │       ▼                          │
                    │  imu_state_t (shared, mutex)     │
                    │       │                          │
                    │       ▼                          │
                    │  attitude_controller (500 Hz)    │
                    │   ├─ Angle PID (pitch, roll)     │
                    │   ├─ Rate PID (pitch, roll, yaw) │
                    │   ├─ Altitude PID + vel damping  │
                    │   └─ Motor Mixer (Quad-X)        │
                    │       │                          │
                    │       ▼                          │
                    │  motor_output (LEDC PWM)         │
                    │       │                          │
                    │  udp_comm (TX, 50 Hz) ───────────▶ UDP:4211
                    │                                   │ (commands out)
                    └──────────────────────────────────┘
```

In hardware mode, `sensor_fusion` replaces the UDP RX path as the source for `imu_state_t`.

### Shared State

The `imu_state_t` struct is the central data exchange between tasks, protected by a FreeRTOS mutex:

```c
typedef struct {
    float pitch, yaw, roll;     // Fused attitude (degrees)
    float altitude;             // Barometric altitude (meters)
    float vx, vy, vz;          // Velocity estimate (m/s)
    float heading;              // Compass heading (degrees)
    float speed;                // Horizontal speed (m/s)
    bool active;                // Armed state
} imu_state_t;
```

## Control System

### Dual-Loop PID Architecture

The attitude controller uses cascaded PID loops. The outer loop converts angle errors into rate setpoints. The inner loop converts rate errors into motor commands.

```
Setpoint (degrees)
       │
       ▼
  ┌─────────┐     rate setpoint (°/s)     ┌─────────┐     motor output
  │Angle PID├─────────────────────────────▶│Rate PID ├──────────────────▶
  │ Kp=4.0  │      (clamped ±200)         │Kp=0.005 │    (clamped ±1)
  └─────────┘                              │Ki=0.001 │
       ▲                                   │Kd=0.0002│
       │                                   └─────────┘
  Fused angle                                   ▲
  (from sensor fusion)                          │
                                          Angular rate
                                     (derived from attitude)
```

This structure is applied independently for pitch and roll.

### Yaw Control

Yaw uses a single rate-mode PID (no angle loop) since magnetometer-free yaw has unbounded drift:

```
Yaw rate setpoint (°/s) ──▶ Yaw PID (Kp=0.01, Ki=0.005) ──▶ yaw output (±1)
```

### Altitude Hold

```
Alt setpoint (m) ──▶ Alt PID (Kp=0.5, Ki=0.1, Kd=0.2) ──▶ correction
                                                                │
Vertical velocity ──▶ Vel Damping (Kp=0.3) ─────────────────▶  │
                                                                ▼
                                              Throttle = 0.5 + correction + damping
                                              (clamped 0..1)
```

The altitude setpoint can be adjusted by the throttle stick input.

### Motor Mixer (Quad-X)

Converts throttle + attitude corrections into per-motor outputs:

```
M0 (FR, CW)  = Throttle - Roll - Pitch - Yaw
M1 (FL, CCW) = Throttle + Roll - Pitch + Yaw
M2 (RL, CW)  = Throttle + Roll + Pitch - Yaw
M3 (RR, CCW) = Throttle - Roll + Pitch + Yaw
```

All outputs clamped to [0, 1] before PWM mapping.

### PWM Output

- Frequency: 50 Hz (20 ms period, standard for ESCs)
- Resolution: 16-bit LEDC timer
- Pulse range: 1000 us (idle) to 2000 us (full throttle)
- Mapping: `duty = 3277 + motorValue * 3277` (where motorValue is 0..1)

## Sensor Fusion

When `USE_REAL_SENSORS=1`, the sensor fusion task runs a complementary filter at 500 Hz:

```
pitch = α * (pitch + gyroY * dt) + (1 - α) * accelPitch
roll  = α * (roll  + gyroX * dt) + (1 - α) * accelRoll
yaw  += gyroZ * dt   (gyro integration only, drifts without magnetometer)
```

- **Alpha (α) = 0.98** -- Trusts the gyroscope 98% for fast response, corrects drift with accelerometer 2%
- **Barometer sampled at 25 Hz** (every 20th control loop tick) to avoid I2C bus contention
- **MPU6050 config**: DLPF at 42 Hz, gyro ±500 deg/s, accel ±4g

## Failsafe

If no telemetry packet is received for 200 ms (`FAILSAFE_TIMEOUT_MS`):
- All motor outputs go to zero
- Altitude hold disengages
- PID integrators reset
- Status LED enters fast-blink error pattern

Telemetry broadcasting continues so the dashboard can still monitor the drone state.

## PID Tuning Guide

### Using the Firmware Emulator

The web-based emulator at `http://localhost:3000/emulator.html` lets you adjust PID gains in real-time with sliders and immediately see the effect on motor outputs and attitude. This is the fastest way to iterate.

### Tuning Order

1. **Rate PID first** -- Set angle Kp to 0, manually input rate setpoints. Increase rate Kp until the drone responds crisply without oscillation. Add Ki to eliminate steady-state error. Add Kd to dampen overshoot.

2. **Angle PID second** -- With a good rate loop, increase angle Kp until the drone tracks angle setpoints. The default Kp=4.0 works well for most 250mm quads.

3. **Altitude PID** -- Tune with the drone hovering. Increase Kp for tighter altitude hold. Add Ki to eliminate drift. Kd dampens vertical oscillation.

4. **Yaw PID last** -- Usually requires minimal tuning. Increase Kp if yaw response is sluggish.

### Default Gains

| Controller | Kp | Ki | Kd | Integral Limit | Output Range |
|------------|-----|------|--------|---------------|--------------|
| Pitch/Roll Angle | 4.0 | 0.0 | 0.0 | 30 | ±200 deg/s |
| Pitch/Roll Rate | 0.005 | 0.001 | 0.0002 | 0.3 | ±1.0 |
| Yaw Rate | 0.01 | 0.005 | 0.0 | 0.3 | ±1.0 |
| Altitude | 0.5 | 0.1 | 0.2 | 0.3 | ±0.5 |

### Anti-Windup

All PID controllers clamp their integral term to prevent windup during saturation. The default integral limit is 0.3 for all controllers.

## Component Reference

| Component | Header | Source | Purpose |
|-----------|--------|--------|---------|
| PID Controller | `pid_controller.h` | `pid_controller.c` | Reusable PID with anti-windup |
| Motor Mixer | `motor_mixer.h` | `motor_mixer.c` | Quad-X mixing matrix |
| Motor Output | `motor_output.h` | `motor_output.c` | LEDC PWM driver |
| Attitude Controller | `attitude_controller.h` | `attitude_controller.c` | Dual-loop PID, altitude hold |
| Sensor Fusion | `sensor_fusion.h` | `sensor_fusion.c` | Complementary filter |
| MPU6050 | `mpu6050.h` | `mpu6050.c` | I2C accelerometer/gyroscope |
| BMP280 | `bmp280.h` | `bmp280.c` | I2C barometer |
| Binary Protocol | `binary_protocol.h` | `binary_protocol.c` | Packet framing and parsing |
| UDP Comm | `udp_comm.h` | `udp_comm.c` | Network TX/RX |
| WiFi Manager | `wifi_manager.h` | `wifi_manager.c` | WiFi STA connection |
| Status LED | `status_led.h` | `status_led.c` | GPIO blink patterns |
