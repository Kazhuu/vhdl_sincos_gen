#!/usr/bin/python

"""
Test sine/cosine core via serial port.

Sends a series of commands to the test driver via the serial port
and verifies answers.

Usage:
  python test_sincos_serial.py /dev/ttyUSB0
"""


from __future__ import print_function
import sys
import numpy
import serial
import struct


def testPhase(dev, coresel, databits, phasebits, phase):

    print("\r phase=%-10d" % phase, end='')
    sys.stdout.flush()

    dev.write(struct.pack("<BBI", 0x41, 0x42 + coresel, phase))

    reply = dev.read(8)

    if len(reply) != 8:
        print()
        print("ERROR: got %d bytes from serial port while expecting 8" %
              len(reply))
        return

    (vsin, vcos) = struct.unpack("<ii", reply)

    ampl  = (1 << (databits - 1)) - 1
    theta = 2 * numpy.pi * phase / 2.0**phasebits
    refsin = ampl * numpy.sin(theta)
    refcos = ampl * numpy.cos(theta)

    if abs(vsin - refsin) > 1.5 or abs(vcos - refcos) > 1.5:
        print()
        print("phase=%d sin=%d cos=%d refsin=%.2f refcos=%.2f" %
              (phase, vsin, vcos, refsin, refcos))
        print("ERROR: wrong answer")


def testCore(dev, clkmod, coresel, databits, phasebits):

    if clkmod:
        # Start clock-enable modulation.
        dev.write("AD")
    else:
        # Stop clock-enable modulation.
        dev.write("AE")

    print("test least significant phase bits")
    for p in range(64):
        phase = p
        testPhase(dev, coresel, databits, phasebits, phase)
    print()

    print("test most significant phase bits")
    for p in range(64):
        phase = p << (phasebits - 6)
        testPhase(dev, coresel, databits, phasebits, phase)
    print()

    print("test pseudorandom phase values")
    phase = 0
    for i in range(5000):
        phase = (phase + 123457) & ((1 << phasebits) - 1)
        testPhase(dev, coresel, databits, phasebits, phase)
    print()


def main():

    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        print("ERROR: Invalid/missing command line arguments", file=sys.stderr)
        sys.exit(1)

    devname = sys.argv[1]

    # Open serial port.
    print("opening serial port", devname)
    dev = serial.Serial(port=devname,
                        baudrate=115200,
                        bytesize=8,
                        parity='N',
                        stopbits=1,
                        timeout=1)

    # Flush input.
    print("flush serial port buffer")
    dev.flushInput()
    dev.flushOutput()
    dev.read(1000)

    # Write series of Z to force test driver to idle state.
    dev.write("ZZZZZZZZ")

    print()
    print('Test 18-bit data, 20-bit phase core')
    testCore(dev, 0, 0, 18, 20)
    print()

    print('Test 24-bit data, 26-bit phase core')
    testCore(dev, 0, 1, 24, 26)
    print()

    print('Test 18-bit data, 20-bit phase core with clock-enable modulation')
    testCore(dev, 1, 0, 18, 20)
    print()

    print('Test 24-bit data, 26-bit phase core with clock-enable modulation')
    testCore(dev, 1, 1, 24, 26)
    print()

    # Close serial port.
    dev.close()

    print("done")


if __name__ == '__main__':
    main()

