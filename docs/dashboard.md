# Dashboard & Tools Guide

The web dashboard provides three interactive tools for monitoring, emulating, and understanding the drone system. All three are served from a single Node.js server with zero build steps.

## Running the Dashboard

```bash
cd dashboard
npm install    # first time only -- installs ws (WebSocket library)
npm start      # starts on http://localhost:3000
```

The server binds:
- **HTTP port 3000** -- Serves static files from `public/`
- **UDP port 4210** -- Listens for telemetry from the Godot simulator
- **WebSocket** -- Broadcasts decoded telemetry to all connected browser clients

### Pages

| URL | Page | Purpose |
|-----|------|---------|
| `/` | Telemetry Dashboard | Live flight data from the Godot simulator |
| `/emulator.html` | Firmware Emulator | Standalone emulation of the firmware control loop |
| `/circuit.html` | Circuit Diagram | Interactive wiring schematic with educational tooltips |

Each page has nav links to the other two in its header.

---

## Telemetry Dashboard

**URL:** `http://localhost:3000`

Connects to the Godot simulator via WebSocket and displays real-time flight data.

### Features

- **Artificial horizon** -- Pitch and roll visualization with sky/ground split
- **Compass** -- Heading indicator with cardinal directions
- **Flight data panel** -- Altitude, speed, climb rate, position
- **Motor RPM bars** -- Color-coded per motor with percentage labels
- **Packet log** -- Raw telemetry data with syntax highlighting
- **Connection status** -- Green/red indicator with packet rate counter

### Data Flow

```
Godot ──UDP:4210──▶ server.mjs ──WebSocket──▶ index.html (browser)
```

The server auto-detects binary vs JSON packets. Binary packets (starting with `0xAA`) are decoded using the protocol spec. JSON packets are parsed directly. Both are forwarded as JSON over WebSocket.

### WebSocket Message Format

```json
{
  "type": "telemetry",
  "data": {
    "t": 12345,
    "pos": [0.5, 5.2, -1.3],
    "vel": [0.1, 0.3, -0.05],
    "att": [2.1, -0.5, 1.3],
    "hdg": 45.0,
    "spd": 3.2,
    "active": true,
    "preset": "Quadcopter",
    "motors": [3000, 4500, 3200, 4100]
  },
  "rate": 50
}
```

---

## Firmware Emulator

**URL:** `http://localhost:3000/emulator.html`

A self-contained emulation of the entire firmware control loop, running in the browser. No ESP32 or simulator needed.

### What It Emulates

Every firmware component is ported from the original C source to JavaScript:

| Firmware Component | C Source | JS Implementation |
|---|---|---|
| PID Controller | `pid_controller.c` | `class PID` with anti-windup |
| Motor Mixer | `motor_mixer.c` | `motorMix()` Quad-X matrix |
| Sensor Fusion | `sensor_fusion.c` | Complementary filter, alpha=0.98 |
| Attitude Controller | `attitude_controller.c` | Dual-loop PID + altitude hold |
| Motor Output | `motor_output.c` | `motorToPwm()` mapping |

A simple 6DOF physics simulation generates realistic sensor readings (accelerometer, gyroscope, barometer with noise) and responds to motor outputs with thrust, torque, gravity, and drag.

### Layout

```
┌──────────────────────────────────────────────────────────────┐
│ FIRMWARE EMULATOR  [ARM] [RESET]            500Hz  CPU%      │
├────────────────┬──────────────────────┬──────────────────────┤
│ HARDWARE       │ DRONE VIEW           │ VIRTUAL STICKS       │
│ COMPONENTS     │ (top-down canvas)    │ (throttle/yaw,       │
│                │                      │  pitch/roll)         │
│ - Battery      │                      │                      │
│ - ESP32        │                      │ ATTITUDE             │
│ - MPU6050      │ SIGNAL PIPELINE      │ (pitch/roll/yaw/alt) │
│ - BMP280       │ Fusion → Angle PID   │                      │
│ - ESC + Motors │ → Rate PID → Mixer   │ PID TUNING           │
│ - Status LED   │ → PWM Output         │ (6 sliders)          │
│                │                      │                      │
│                │ SIGNAL MONITOR        │ MOTOR OUTPUT         │
│                │ (rolling graphs)     │ (4 bar indicators)   │
└────────────────┴──────────────────────┴──────────────────────┘
```

### Controls

**Virtual Joysticks** -- Click and drag. Left stick = throttle/yaw, right stick = pitch/roll. Release returns to center.

**Keyboard:**

| Key | Function |
|-----|----------|
| W / S | Throttle up/down |
| A / D | Yaw left/right |
| I / K | Pitch forward/back |
| J / L | Roll left/right |

**PS4 / DualShock 4 / DualSense Gamepad:**

| Control | Function |
|---------|----------|
| Left Stick | Throttle (Y) / Yaw (X) |
| Right Stick | Pitch (Y) / Roll (X) |
| L2 / R2 Triggers | Fine throttle trim |
| Triangle | Arm / Disarm toggle |
| Circle | Reset |

The gamepad is detected automatically via the browser Gamepad API. Press any button on the controller to wake it up. The header shows the gamepad name in green when connected.

When a gamepad is active, it takes full control -- keyboard and virtual sticks are ignored to prevent input conflicts.

### PID Tuning

Six real-time sliders let you adjust PID gains while the emulator runs:

| Slider | Default | Affects |
|--------|---------|---------|
| Angle Kp | 4.0 | Pitch/Roll angle PID proportional |
| Rate Kp | 0.005 | Pitch/Roll rate PID proportional |
| Rate Ki | 0.001 | Pitch/Roll rate PID integral |
| Rate Kd | 0.0002 | Pitch/Roll rate PID derivative |
| Alt Kp | 0.5 | Altitude hold proportional |
| Yaw Kp | 0.01 | Yaw rate proportional |

Changes take effect immediately. Use this to understand how each gain affects stability.

### Signal Graphs

Three rolling graph strips at the bottom show:
- **Attitude** -- Pitch (red), Roll (teal), Yaw (orange) in degrees
- **Motors** -- M0--M3 output percentages
- **Altitude** -- Actual altitude (cyan) vs setpoint (yellow)

### Emulation Timing

The firmware runs at a fixed 500 Hz timestep (2 ms). The browser accumulates real time and runs multiple firmware ticks per animation frame to maintain the correct rate. A cap of 20 steps per frame prevents spiral-of-death on slow machines.

---

## Circuit Diagram

**URL:** `http://localhost:3000/circuit.html`

An interactive, animated wiring schematic showing how all hardware components connect. Designed to be educational and accessible for kids learning circuit design.

### What It Shows

**ESP32 Pinout** -- Full DevKit V1 board rendering with all 26 pins. Active pins glow with color-coded function labels:
- Purple: I2C (GPIO 21 SDA, GPIO 22 SCL)
- Green: PWM motor outputs (GPIO 25, 26, 27, 14)
- Yellow: Status LED (GPIO 2)
- Orange: Power (VIN 5V, 3V3)
- Dimmed: Unused pins

**Internal Architecture** -- The ESP32 chip shows its dual-core layout:
- Core 0: Sensor Fusion, WiFi + UDP, I2C Driver
- Core 1: Attitude Control, PID x6, Motor Mixer, PWM Output

**Sensor Chips** -- MPU6050 and BMP280 with I2C addresses, specifications, and data rate.

**ESCs + Motors** -- Four ESC/motor pairs with:
- Power bar showing current output level
- Spinning prop disc animation (speed proportional to throttle)
- CW/CCW rotation direction
- PWM waveform drawn inline on the signal wire

**Power System** -- Battery (4S LiPo) to PDB to ESCs, with a 5V BEC output to the ESP32.

**WiFi** -- Animated radio waves from the built-in antenna.

### Signal Flow Animation

Colored particles flow along the wires to show data direction:
- **Purple particles**: I2C data (SDA/SCL) between sensors and ESP32
- **Green particles**: PWM signals from ESP32 to ESCs (only when armed)
- **Orange particles**: Power flowing from battery through PDB
- **Blue particles**: WiFi/UDP data (dashed line)

Toggle animation with the **Signals ON/OFF** button in the header.

### Educational Annotations

Three explanation boxes teach fundamental concepts:

**"What is I2C?"** -- Explains the 2-wire protocol: SDA (data) and SCL (clock), how multiple chips share one bus.

**"What is PWM?"** -- Explains pulse width modulation with two side-by-side waveform examples at 30% and 80% duty cycle.

**"Power Flow"** -- Traces the voltage path: Battery (14.8V) to PDB to ESCs (14.8V) and BEC to ESP32 (5V) to sensors (3.3V).

**Quad-X Motor Layout** -- Mini diagram showing motor positions, numbers, and CW/CCW rotation directions.

Toggle labels with the **Labels** button in the header.

### Tooltips

Hover over any component to see a detailed tooltip with:
- **Plain-English description** explaining what the component does
- **Signal type badges** (I2C, PWM, Digital, Power, WiFi, etc.)
- **Technical specifications**
- **Mini waveform visualization** showing the signal type:
  - ESP32: 240 MHz clock signal
  - MPU6050: Sine wave (gyro output)
  - BMP280: Noisy altitude trace
  - ESCs: PWM pulse with varying duty cycle
  - LED: On/off blink pattern
  - WiFi: Binary packet showing 0xAA 0x55 sync bytes

---

## Extending the Dashboard

### Adding a New Page

1. Create `dashboard/public/your-page.html`
2. It will be served automatically at `/your-page.html`
3. Add nav links in other pages' headers for discoverability

### Adding WebSocket Data

To broadcast new data types from the server:

1. Edit `dashboard/server.mjs`
2. Process the new data in the UDP message handler
3. Add it to the WebSocket broadcast payload
4. Read it in the browser via `ws.onmessage`

### Adding Telemetry Panels

The telemetry dashboard (`index.html`) uses vanilla JS with canvas rendering. To add a new panel:

1. Add an HTML container in the layout grid
2. Create a render function (canvas-based for performance, or DOM for simple displays)
3. Call it from the WebSocket message handler

### Connecting to Real Hardware

The dashboard works with both the simulator and real ESP32 hardware simultaneously. As long as the ESP32 broadcasts on UDP port 4210, the dashboard server picks it up and forwards to all browser clients. No configuration changes needed.
