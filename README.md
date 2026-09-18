# FPGA Smart Sensor & Gesture Game Controller

FPGA-based smart-sensor system integrating an **ADXL345 accelerometer**, SPI communication, sensor-data processing, gesture classification, UART communication and PC-side keyboard control.

The final application interprets accelerometer motion on the FPGA and transmits **W/A/S/D** commands to a host computer, where a Python application converts them into keyboard events for controlling a game.

The project was originally developed as part of a university smart-sensor laboratory and has been reorganized and refactored here into a modular portfolio implementation.

## System Architecture

```text
                  +----------------------+
                  |      ADXL345         |
                  |    Accelerometer     |
                  +----------+-----------+
                             |
                             | SPI
                             v
                  +----------------------+
                  |   ADXL345 SPI RTL    |
                  +----------+-----------+
                             |
                             v
                  +----------------------+
                  |  Sensor Controller   |
                  |                      |
                  |  Y-axis acquisition  |
                  |  Z-axis acquisition  |
                  +----------+-----------+
                             |
                             v
                  +----------------------+
                  | Gesture Classifier   |
                  |                      |
                  | Left  -> A           |
                  | Right -> D           |
                  | Up    -> W           |
                  | Down  -> S           |
                  +----------+-----------+
                             |
                             v
                  +----------------------+
                  |     UART TX RTL      |
                  +----------+-----------+
                             |
                             | Serial
                             v
                  +----------------------+
                  | Python Host          |
                  | Keyboard Controller  |
                  +----------+-----------+
                             |
                             v
                         PC / Game
```

## Features

- Verilog RTL design for FPGA-based sensor processing
- ADXL345 communication over SPI
- Accelerometer register configuration
- Continuous Y- and Z-axis data acquisition
- FPGA-side gesture classification
- UART transmission of recognized commands
- Python serial interface for PC communication
- Keyboard-event generation using `pynput`
- Modular RTL architecture
- Self-checking simulation of individual interfaces
- End-to-end simulation of the complete gesture-control pipeline

## Gesture Mapping

The gesture classifier preserves the threshold behavior used in the original laboratory implementation.

| Sensor condition | Command | Action |
|---|---|---|
| `20 < Y < 120` | `A` | Left |
| `130 < Y < 230` | `D` | Right |
| `Z > 130` | `W` | Up |
| `Z < 120` | `S` | Down |

Y-axis classifications have priority over Z-axis classifications.

## ADXL345 Configuration

The sensor controller configures the ADXL345 before beginning continuous acquisition.

```text
DATA_FORMAT  0x31 <- 0x01
POWER_CTL    0x2D <- 0x08
```

The application reads:

```text
DATAY0       0x34
DATAY1       0x35
DATAZ0       0x36
DATAZ1       0x37
```

The two bytes for each axis are combined into 16-bit sensor values before gesture classification.

## Repository Structure

```text
rtl/
├── basic/
│   └── mux_design_styles.v
├── counter/
│   └── slow_counter.v
├── pwm/
│   ├── pwm_module.v
│   └── pwm_top.v
├── spi/
│   └── adxl345_spi.v
└── uart/
    └── uart_tx.v

applications/
├── accelerometer_reader/
│   └── top.v
└── gesture_game_controller/
    ├── top.v
    ├── sensor_controller.v
    ├── gesture_classifier.v
    └── host/
        └── keyboard_controller.py

simulations/
├── uart_tx_tb.v
├── adxl345_spi_tb.v
├── accelerometer_reader_tb.v
└── gesture_game_controller_tb.v
```

## RTL Modules

### SPI Interface

`rtl/spi/adxl345_spi.v`

Implements the SPI register-transfer interface used to communicate with the ADXL345 accelerometer.

### UART Transmitter

`rtl/uart/uart_tx.v`

Parameterized UART transmitter used to send sensor information and gesture commands to the host computer.

### Sensor Controller

`applications/gesture_game_controller/sensor_controller.v`

Controls sensor initialization and acquisition.

The controller performs the following sequence:

```text
Configure DATA_FORMAT
        ↓
Enable measurement mode
        ↓
Read Y-axis LSB
        ↓
Read Y-axis MSB
        ↓
Read Z-axis LSB
        ↓
Read Z-axis MSB
        ↓
Publish complete sample
        ↓
Repeat
```

### Gesture Classifier

`applications/gesture_game_controller/gesture_classifier.v`

Converts Y/Z accelerometer measurements into ASCII movement commands.

### Game Controller

`applications/gesture_game_controller/top.v`

Integrates the SPI interface, sensor controller, gesture classifier and UART transmitter into the complete FPGA application.

Repeated transmission of the same gesture is suppressed until the sensor returns to a neutral state or another gesture is detected.

## Host Application

The host-side Python program receives gesture characters from the FPGA and converts them into keyboard events.

Install the required packages:

```bash
python3 -m pip install pyserial pynput
```

Run the program with:

```bash
python3 applications/gesture_game_controller/host/keyboard_controller.py <serial-port>
```

Example on macOS:

```bash
python3 applications/gesture_game_controller/host/keyboard_controller.py /dev/cu.usbserial-XXXX
```

Example on Windows:

```bash
python applications/gesture_game_controller/host/keyboard_controller.py COM6
```

The default UART baud rate is:

```text
9600 baud
```

A different rate can be selected with:

```bash
python3 applications/gesture_game_controller/host/keyboard_controller.py <port> --baud 9600
```

## Simulation

The RTL was tested using Icarus Verilog.

### UART

```bash
iverilog -g2012 \
  -o simulations/uart_tx_tb.out \
  rtl/uart/uart_tx.v \
  simulations/uart_tx_tb.v

vvp simulations/uart_tx_tb.out
```

### SPI

```bash
iverilog -g2012 \
  -o simulations/adxl345_spi_tb.out \
  rtl/spi/adxl345_spi.v \
  simulations/adxl345_spi_tb.v

vvp simulations/adxl345_spi_tb.out
```

### Complete Gesture Controller

```bash
iverilog -g2012 -Wall \
  -o simulations/gesture_game_controller_tb.out \
  rtl/spi/adxl345_spi.v \
  rtl/uart/uart_tx.v \
  applications/gesture_game_controller/sensor_controller.v \
  applications/gesture_game_controller/gesture_classifier.v \
  applications/gesture_game_controller/top.v \
  simulations/gesture_game_controller_tb.v
```

Run:

```bash
vvp simulations/gesture_game_controller_tb.out
```

Expected result:

```text
Gesture command received: A
Gesture command received: D
Gesture command received: W
Gesture command received: S

Gesture game controller end-to-end test PASSED
```

Waveforms can also be inspected using a VCD viewer such as Surfer.

## Technologies

`Verilog` `FPGA` `SPI` `UART` `ADXL345` `Embedded Systems`  
`Digital Design` `Sensor Interfaces` `Python` `Icarus Verilog`  
`Hardware-Software Co-Design`

## Background

This repository is based on work completed during a university smart-sensor laboratory using a **Lattice iCE40 FPGA** and an **ADXL345 accelerometer**.

The laboratory progressed from fundamental Verilog design and PWM generation through UART and SPI interfaces to sensor acquisition and FPGA-side gesture processing.

The portfolio version reorganizes and refactors that work into reusable RTL blocks, clearer interfaces and reproducible simulations.