# FPGA Smart Sensor & Gesture Controller

FPGA-based embedded sensing project implemented in Verilog.

The system reads motion data from an accelerometer over SPI, processes the sensor values on the FPGA, classifies movement commands, and sends the result to a host computer through UART. A small Python application converts the received commands into keyboard events.

## Architecture

```text
Accelerometer
    ↓
SPI
    ↓
Sensor Controller
    ↓
Gesture Processing
    ↓
UART
    ↓
Python Host
