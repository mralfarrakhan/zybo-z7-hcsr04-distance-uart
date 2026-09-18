#!/usr/bin/env python3
"""Serial monitor for the HC-SR04 -> UART distance demo (Zybo Z7-10).

Opens the CP210x USB-UART bridge at 115200 8N1 and prints each
"D=xxxcm" line the FPGA sends once per second.

Usage:
    python serial_monitor.py            # auto-detect CP210x port
    python serial_monitor.py COM13      # use a specific port
    python serial_monitor.py --hex      # also show raw hex bytes
"""

import argparse
import re
import sys
import time

import serial
import serial.tools.list_ports

BAUD_RATE = 115200
LINE_RE = re.compile(r"^D=(\d{3})cm$")


def find_cp210x_port():
    for port in serial.tools.list_ports.comports():
        if "CP210" in (port.description or "") or (port.vid == 0x10C4 and port.pid == 0xEA60):
            return port.device
    return None


def list_ports():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available serial ports:")
    for port in ports:
        print(f"  {port.device}  -  {port.description}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("port", nargs="?", help="Serial port (e.g. COM13). Auto-detects CP210x if omitted.")
    parser.add_argument("--baud", type=int, default=BAUD_RATE, help=f"Baud rate (default {BAUD_RATE})")
    parser.add_argument("--hex", action="store_true", help="Also print raw hex bytes")
    args = parser.parse_args()

    port = args.port or find_cp210x_port()
    if not port:
        print("Could not auto-detect a CP210x port.\n")
        list_ports()
        sys.exit(1)

    try:
        ser = serial.Serial(port, args.baud, timeout=0.1)
    except serial.SerialException as e:
        print(f"Failed to open {port}: {e}\n")
        list_ports()
        sys.exit(1)

    print(f"Listening on {port} @ {args.baud} baud, 8N1. Ctrl+C to quit.\n")

    line_buf = bytearray()
    try:
        while True:
            data = ser.read(256)
            if not data:
                continue

            if args.hex:
                print(" ".join(f"{b:02X}" for b in data))

            for b in data:
                if b == 0x0A:  # LF -> flush line
                    ts = time.strftime("%H:%M:%S")
                    text = line_buf.decode("ascii", errors="replace")
                    line_buf.clear()

                    match = LINE_RE.match(text)
                    if match:
                        print(f"[{ts}] distance = {int(match.group(1))} cm")
                    else:
                        print(f"[{ts}] {text}")
                elif b == 0x0D:  # CR -> ignore, LF ends the line
                    continue
                else:
                    line_buf.append(b)
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
