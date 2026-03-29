# Hardware Parts List

Bill of materials for building a 250mm quadcopter powered by the OpenKB drone firmware.

## Core Electronics

| # | Component | Spec | Qty | Est. Price |
|---|-----------|------|-----|------------|
| 1 | **ESP32 DevKit V1** | ESP-WROOM-32, 240MHz dual-core, Wi-Fi | 1 | $6-10 |
| 2 | **MPU6050 IMU** (GY-521 breakout) | 6-axis accel/gyro, I2C, +/-4g / +/-500dps | 1 | $2-4 |
| 3 | **BMP280 Barometer** (GY-BMP280 breakout) | Pressure/temp/altitude, I2C | 1 | $2-4 |
| 4 | **ESC** (Electronic Speed Controller) | 20A BLHeli_S, PWM input, 2-4S LiPo | 4 | $8-12 ea |
| 5 | **Brushless Motors** | 2205 2300KV, CW+CCW threads | 4 | $8-12 ea |
| 6 | **Propellers** | 5x4.5" or 5x4x3 triblade, 2CW + 2CCW | 2 sets | $3-5/set |

## Frame

| # | Component | Spec | Qty | Est. Price |
|---|-----------|------|-----|------------|
| 7 | **Quadcopter Frame** | 250mm carbon fiber (QAV250 style), X-config | 1 | $15-25 |

## Power

| # | Component | Spec | Qty | Est. Price |
|---|-----------|------|-----|------------|
| 8 | **LiPo Battery** | 4S 1500mAh 14.8V, 75C+ discharge, XT60 | 1 | $20-30 |
| 9 | **Balance Charger** | 2-4S LiPo charger (ISDT Q6 or similar) | 1 | $30-50 |
| 10 | **Power Distribution Board** | With 5V BEC output for ESP32 | 1 | $5-8 |
| 11 | **XT60 Pigtail** | Male connector with leads for battery | 1 | $2-3 |

## Wiring & Mounting

| # | Component | Spec | Qty | Est. Price |
|---|-----------|------|-----|------------|
| 12 | **Silicone Wire** | 14 AWG (power), 22 AWG (signal) | 1m each | $3-5 |
| 13 | **M3 Standoffs** | Nylon, 6-10mm, for FC stack mounting | 8 | $2-3 |
| 14 | **Heat Shrink Tubing** | Assorted sizes | 1 set | $2-3 |
| 15 | **Zip Ties** | Small, for cable management | 1 bag | $1-2 |
| 16 | **Double-Sided Foam Tape** | Vibration-dampening, for FC mount | 1 roll | $2-3 |

## Optional Additions

| # | Component | Spec | Qty | Est. Price |
|---|-----------|------|-----|------------|
| 17 | **GPS Module** (BN-880) | GPS + compass (HMC5883L), UART | 1 | $12-18 |
| 18 | **Buzzer** | 5V active, for lost-drone alarm | 1 | $1-2 |
| 19 | **RC Receiver** (FrSky XM+) | SBUS, for manual override | 1 | $12-18 |
| 20 | **LiPo Voltage Monitor** | Buzzer alarm at low voltage | 1 | $2-3 |

## Estimated Total

| Build | Cost |
|-------|------|
| Minimum (no optional parts) | ~$120-150 |
| Full build (with GPS + receiver) | ~$160-200 |

---

## Wiring Diagram

```
                         ESP32 DevKit V1
                    ┌──────────────────────┐
                    │                      │
     Motor 0 (FR) ←│ GPIO 25         3V3  │→ MPU6050 VCC, BMP280 VCC
     Motor 1 (FL) ←│ GPIO 26         GND  │→ MPU6050 GND, BMP280 GND
     Motor 2 (RL) ←│ GPIO 27              │
     Motor 3 (RR) ←│ GPIO 14         5V   │← PDB 5V BEC
                    │                      │
    I2C SDA  ←────→│ GPIO 21              │
    I2C SCL  ←────→│ GPIO 22              │
                    │                      │
    Status LED ←───│ GPIO 2               │
                    └──────────────────────┘

    I2C Bus (shared, 400kHz):
    ┌──────────┐    ┌──────────┐
    │ MPU6050  │    │ BMP280   │
    │ Addr 0x68│    │ Addr 0x76│
    │ SDA ─────┼────┼── SDA    │
    │ SCL ─────┼────┼── SCL    │
    └──────────┘    └──────────┘

    Motor Layout (top-down, Quad-X):

          Front
      M1(FL,CCW)   M0(FR,CW)
           ╲         ╱
            ╲       ╱
             ╲     ╱
              ─────
             ╱     ╲
            ╱       ╲
           ╱         ╲
      M2(RL,CW)    M3(RR,CCW)
          Rear

    ESC Wiring:
    ┌──────────────────────────────────────────────┐
    │  PDB ──[+/−]──→ ESC 0 ──[3-wire]──→ Motor 0 │
    │       ──[+/−]──→ ESC 1 ──[3-wire]──→ Motor 1 │
    │       ──[+/−]──→ ESC 2 ──[3-wire]──→ Motor 2 │
    │       ──[+/−]──→ ESC 3 ──[3-wire]──→ Motor 3 │
    │       ──[5V BEC]──→ ESP32 5V pin              │
    │                                               │
    │  ESC 0 signal ← GPIO 25                       │
    │  ESC 1 signal ← GPIO 26                       │
    │  ESC 2 signal ← GPIO 27                       │
    │  ESC 3 signal ← GPIO 14                       │
    └──────────────────────────────────────────────┘

    Battery:
    [4S LiPo XT60] ──→ [PDB XT60 input]
```

## Pin Reference (from app_config.h)

| GPIO | Function | Notes |
|------|----------|-------|
| 25 | Motor 0 (Front-Right, CW) | LEDC PWM Ch 0, 50Hz |
| 26 | Motor 1 (Front-Left, CCW) | LEDC PWM Ch 1, 50Hz |
| 27 | Motor 2 (Rear-Left, CW) | LEDC PWM Ch 2, 50Hz |
| 14 | Motor 3 (Rear-Right, CCW) | LEDC PWM Ch 3, 50Hz |
| 21 | I2C SDA | MPU6050 + BMP280 (shared bus) |
| 22 | I2C SCL | 400kHz fast mode |
| 2 | Status LED | On-board LED on most DevKits |

## Safety Notes

- Always remove propellers when testing firmware on a bench.
- Use a smoke stopper (inline fuse) on first power-up to protect against shorts.
- Never charge LiPo batteries unattended.
- Set ESC low-voltage cutoff to 3.3V/cell (13.2V for 4S) to protect battery.
- The ESP32 runs on 3.3V logic; most ESCs accept 3.3V signal but verify your ESC datasheet.
