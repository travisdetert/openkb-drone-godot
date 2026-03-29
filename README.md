# OpenKB Drone

An open-source quadcopter simulator and flight controller platform built with Godot 4.6 and ESP32. Fly a drone in a 3D simulator, develop real firmware, and seamlessly transition to physical hardware.

```
    Godot Simulator          ESP32 Firmware          Web Dashboard
   ┌──────────────┐       ┌──────────────────┐     ┌──────────────┐
   │  3D Physics   │──UDP──│  PID Controller   │     │  Telemetry   │
   │  Drone Model  │       │  Motor Mixer      │     │  Emulator    │
   │  Environment  │       │  Sensor Fusion    │     │  Circuit Viz │
   └──────────────┘       └──────────────────┘     └──────────────┘
         ↕                        ↕                        ↕
    UDP Telemetry            Binary Protocol          WebSocket
      (port 4210)           (0xAA55 framed)          (port 3000)
```

## What's Inside

**Godot 3D Simulator** -- Full drone flight sim with crash physics, FPV camera, multiple drone presets (quad/hex/octo), speed profiles, racing obstacles, and gamepad support.

**ESP32 Flight Controller Firmware** -- Production-grade C firmware (ESP-IDF/FreeRTOS) with dual-loop PID attitude control, complementary filter sensor fusion, quad-X motor mixing, and altitude hold. Runs at 500 Hz on dual cores.

**Binary Communication Protocol** -- Efficient framed packet protocol with TypeScript encoder/decoder specs. Supports motor commands, arm/disarm, configuration, telemetry, and heartbeat.

**Web Dashboard** -- Three interactive tools served from a single Node.js server:
- **Telemetry Dashboard** -- Real-time artificial horizon, compass, motor RPM bars, flight data
- **Firmware Emulator** -- JS port of the full firmware control loop with virtual joysticks, PS4 gamepad support, PID tuning sliders, and signal graphs
- **Circuit Diagram** -- Animated ESP32 pinout and wiring schematic with kid-friendly educational tooltips

## Quick Start

### Simulator Only (no hardware needed)

1. Open the project in [Godot 4.6+](https://godotengine.org/download)
2. Press F5 to run
3. Fly with keyboard (WASD/Space/Arrows) or a gamepad

### Dashboard

```bash
cd dashboard
npm install
npm start
# Open http://localhost:3000
```

Three pages are available:
- `/` -- Telemetry dashboard (connects to Godot via UDP)
- `/emulator.html` -- Standalone firmware emulator
- `/circuit.html` -- Interactive circuit diagram

### Firmware (requires ESP-IDF)

```bash
# Install ESP-IDF v5.0+: https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/
cd firmware
idf.py set-target esp32
idf.py build
idf.py flash -p /dev/ttyUSB0
idf.py monitor -p /dev/ttyUSB0
```

Before flashing, edit `main/app_config.h` to set your WiFi credentials:
```c
#define WIFI_SSID "your-ssid"
#define WIFI_PASS "your-password"
```

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        WiFi Network                             │
├─────────────┬──────────────────────────┬────────────────────────┤
│             │                          │                        │
│   Godot Sim │    ESP32 Controller      │   Dashboard Server     │
│             │                          │                        │
│  ┌────────┐ │  ┌───────────────────┐   │  ┌──────────────────┐  │
│  │Physics │ │  │ Core 0            │   │  │ Node.js          │  │
│  │Engine  │ │  │  Sensor Fusion    │   │  │  HTTP :3000      │  │
│  │        │─┼──│  WiFi + UDP       │   │  │  UDP  :4210      │  │
│  │Keyboard│ │  │  I2C Driver       │   │  │  WebSocket       │  │
│  │Gamepad │ │  ├───────────────────┤   │  └──────┬───────────┘  │
│  │        │ │  │ Core 1            │   │         │              │
│  │UDP Net │ │  │  Attitude Control │   │  ┌──────▼───────────┐  │
│  │        │ │  │  PID x6           │   │  │ Browser          │  │
│  │Crash   │ │  │  Motor Mixer      │   │  │  Telemetry       │  │
│  │Effects │ │  │  PWM Output       │   │  │  Emulator        │  │
│  └────────┘ │  └───────────────────┘   │  │  Circuit Diagram │  │
│             │                          │  └──────────────────┘  │
└─────────────┴──────────────────────────┴────────────────────────┘

Data Flow:
  Godot ──telemetry (UDP:4210)──▶ ESP32 + Dashboard
  ESP32 ──commands  (UDP:4211)──▶ Godot
```

### Firmware Control Loop (500 Hz)

```
IMU Sensors ──▶ Sensor Fusion ──▶ Attitude Controller ──▶ Motor Mixer ──▶ PWM Output
                (complementary       (dual-loop PID)        (Quad-X)      (50Hz ESC)
                 filter, α=0.98)
                                         │
                          ┌──────────────┤
                          │              │
                     Angle PID      Rate PID
                    (Kp=4.0)      (Kp=0.005)
                          │         Ki=0.001
                    rate setpoint   Kd=0.0002
                    (±200°/s)         │
                                 motor output
                                   (±1.0)
```

### Motor Layout (Quad-X)

```
        Front ▲
   M1 (FL,CCW)   M0 (FR,CW)
        ╲           ╱
         ╲         ╱
          ●───────●
         ╱         ╲
        ╱           ╲
   M2 (RL,CW)    M3 (RR,CCW)

   Mix Matrix:
   M0 = Throttle - Roll - Pitch - Yaw
   M1 = Throttle + Roll - Pitch + Yaw
   M2 = Throttle + Roll + Pitch - Yaw
   M3 = Throttle - Roll + Pitch + Yaw
```

## Controls

### Simulator

| Input | Keyboard | Gamepad |
|-------|----------|---------|
| Throttle Up/Down | Space / Down Arrow | Left Stick Y |
| Pitch Forward/Back | W / S | Right Stick Y |
| Roll Left/Right | A / D | Right Stick X |
| Yaw Left/Right | Q / E | Left Stick X |
| Arm/Toggle | Left Ctrl | A Button |
| Reset | R | B Button |
| Camera Mode | C | X Button |
| Config Panel | Left Shift | Menu |
| Preset Up/Down | 1 / 2 | D-Pad Up/Down |
| Blade Count | 3 / 4 | D-Pad Left/Right |

### Firmware Emulator

| Input | Keyboard | PS4 Gamepad |
|-------|----------|-------------|
| Throttle | W / S | Left Stick Y |
| Yaw | A / D | Left Stick X |
| Pitch | I / K | Right Stick Y |
| Roll | J / L | Right Stick X |
| Throttle Trim | -- | L2 / R2 |
| Arm/Disarm | Click ARM button | Triangle |
| Reset | Click RESET button | Circle |

## Drone Presets

| Preset | Motors | Mass | Arm Length | Max RPM |
|--------|--------|------|------------|---------|
| Quadcopter | 4 | 1.2 kg | 0.25 m | 12,000 |
| Hexacopter | 6 | 2.0 kg | 0.30 m | 11,000 |
| Octocopter | 8 | 3.5 kg | 0.35 m | 10,000 |

Each preset supports 4 speed profiles: Slow, Normal, Fast, and Ludicrous.

## Hardware Build

See [HARDWARE.md](HARDWARE.md) for the complete bill of materials, wiring diagram, and assembly notes.

**Estimated cost:** $120--200 depending on component choices.

**Core components:**
- ESP32 DevKit V1 (ESP-WROOM-32)
- MPU6050 6-axis IMU (GY-521)
- BMP280 Barometer (GY-BMP280)
- 4x 20A BLHeli_S ESC
- 4x 2205 2300KV Brushless Motor
- 250mm Carbon Fiber Frame
- 4S 1500mAh LiPo Battery

## Detailed Documentation

- [Firmware Guide](docs/firmware.md) -- Build, flash, architecture, PID tuning, simulator vs hardware modes
- [Protocol Specification](docs/protocol.md) -- Binary packet format, command/telemetry types, encoding examples
- [Dashboard & Tools](docs/dashboard.md) -- Telemetry dashboard, firmware emulator, circuit diagram, extending the tools

## Project Structure

```
openkb-drone-godot/
├── project.godot              # Godot engine configuration
├── HARDWARE.md                # Bill of materials and wiring
├── scripts/                   # GDScript source
│   ├── main.gd               # Root scene controller
│   ├── drone/                 # Drone physics, config, builder
│   ├── input/                 # Keyboard and gamepad input
│   ├── camera/                # Camera modes (third-person, FPV, free)
│   ├── net/                   # UDP telemetry networking
│   ├── ui/                    # HUD panels and indicators
│   ├── effects/               # Crash effects (debris, smoke)
│   └── environment/           # World, obstacles, racing hoops
├── firmware/                  # ESP32 flight controller (C / ESP-IDF)
│   ├── main/                  # Entry point and configuration
│   └── components/            # Modular firmware components
│       ├── attitude_controller/
│       ├── pid_controller/
│       ├── motor_mixer/
│       ├── motor_output/
│       ├── sensor_fusion/
│       ├── mpu6050/
│       ├── bmp280/
│       ├── binary_protocol/
│       ├── udp_comm/
│       ├── wifi_manager/
│       └── status_led/
├── protocol/                  # TypeScript protocol specifications
│   ├── command-spec.ts
│   └── telemetry-spec.ts
├── dashboard/                 # Web dashboard (Node.js)
│   ├── server.mjs             # HTTP + WebSocket + UDP server
│   └── public/
│       ├── index.html         # Telemetry dashboard
│       ├── emulator.html      # Firmware emulator
│       └── circuit.html       # Interactive circuit diagram
└── docs/                      # Documentation
    ├── firmware.md
    ├── protocol.md
    └── dashboard.md
```

## License

MIT
