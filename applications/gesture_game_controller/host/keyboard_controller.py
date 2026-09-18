#!/usr/bin/env python3

"""
Host-side keyboard controller for the FPGA gesture game controller.

The FPGA sends one of the following ASCII characters over UART:

    W -> Up
    A -> Left
    S -> Down
    D -> Right

The received character is converted into a keyboard press using pynput.
"""

import argparse
import time

import serial
from pynput.keyboard import Controller


VALID_COMMANDS = {
    "W": "w",
    "A": "a",
    "S": "s",
    "D": "d",
}


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Receive FPGA gesture commands over UART and generate keyboard input."
    )

    parser.add_argument(
        "port",
        help="Serial port, e.g. COM6 or /dev/cu.usbserial-XXXX",
    )

    parser.add_argument(
        "--baud",
        type=int,
        default=9600,
        help="UART baud rate (default: 9600)",
    )

    parser.add_argument(
        "--hold-time",
        type=float,
        default=0.05,
        help="Duration of each simulated key press in seconds (default: 0.05)",
    )

    return parser.parse_args()


def main():
    args = parse_arguments()

    keyboard = Controller()

    print("FPGA Gesture Game Controller")
    print(f"Serial port : {args.port}")
    print(f"Baud rate   : {args.baud}")
    print("Waiting for W/A/S/D commands...")
    print("Press Ctrl+C to stop.\n")

    try:
        with serial.Serial(
            port=args.port,
            baudrate=args.baud,
            timeout=0.1,
        ) as uart:

            while True:
                raw_data = uart.read(1)

                if not raw_data:
                    continue

                try:
                    command = raw_data.decode("ascii").upper()
                except UnicodeDecodeError:
                    continue

                if command not in VALID_COMMANDS:
                    continue

                key = VALID_COMMANDS[command]

                print(f"Gesture: {command} -> key: {key}")

                keyboard.press(key)
                time.sleep(args.hold_time)
                keyboard.release(key)

    except serial.SerialException as error:
        print(f"Serial error: {error}")

    except KeyboardInterrupt:
        print("\nController stopped.")


if __name__ == "__main__":
    main()