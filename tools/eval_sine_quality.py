#!/usr/bin/python

"""
Evaluate quality of generated sine/cosine waveform.

Reads output file from VHDL testbench and reports
key figures for the quality of the sine wave.

Usage:
  python eval_sine_quality.py datafile.dat
"""


from __future__ import print_function
import sys
import numpy


def read_data(fname):

    n = 0
    data = numpy.zeros((1024, 2), dtype=numpy.int64)

    with open(fname, 'r') as f:
        for s in f:
            if n == data.shape[0]:
                data = numpy.resize(data, (2*n, 2))
            w = s.split()
            assert len(w) == 2
            if len(w) != 2:
                raise ValueError("Expecting two columns in file")
            data[n,0] = int(w[0])
            data[n,1] = int(w[1])
            n += 1

    return data[:n,:]


def eval_sine_quality(data):

    assert len(data.shape) == 2
    assert data.shape[1] == 2
    n = data.shape[0]
    assert n >= 4 and n % 4 == 0

    # Extract sine and cosine colums.
    dsin = numpy.copy(data[:,0])
    dcos = data[:,1]
    del data

    # Check that cosine is an exact phase-shifted version of sine.
    dcos[0:3*n//4] -= dsin[n//4:]
    dcos[3*n//4:]  -= dsin[0:n//4]
    tmin = numpy.amin(dcos)
    tmax = numpy.amax(dcos)
    del dcos

    if tmin == 0 and tmax == 0:
        print('cos(x) == sin(x+pi/2) exactly')
    else:
        print('cos(x) == sin(x+pi/2) + (%d .. %d)' % (tmin, tmax))

    # Check that 180 degree phase shift is equivalent to sign negation.
    t = dsin[0:n//2] + dsin[n//2:]
    tmin = numpy.amin(t)
    tmax = numpy.amax(t)
    del t

    if tmin == 0 and tmax == 0:
        print('sin(x) == - sin(x+pi) exactly')
    else:
        print('sin(x) == - sin(x+pi) + (%d .. %d)' % (tmin, tmax))
    print()

    # Determine offset (mean value of waveform).
    offs = numpy.mean(dsin)
    print('offset =        %20.12f lsb' % offs)

    # Determine amplitude and phase.
    tref = numpy.sin(2 * numpy.pi / n * numpy.arange(n))
    asin = numpy.sum(dsin * tref) * 2.0 / n
    del tref
    tref = numpy.cos(2 * numpy.pi / n * numpy.arange(n))
    acos = numpy.sum(dsin * tref) * 2.0 / n
    del tref

    ampl   = numpy.sqrt(asin**2 + acos**2)
    phase  = numpy.arctan2(acos, asin)

    print('amplitude =     %20.12f lsb' % ampl)
    print('phase offset =  %20.12f rad' % phase)
    print()

    # Determine peak and rms deviation.
    tref = ampl * numpy.sin(2 * numpy.pi / n * numpy.arange(n))
    terr = dsin - tref
    del tref

    peakerr = numpy.amax(numpy.abs(terr))
    rmserr  = numpy.std(terr)
    del terr

    print('peak error =    %20.12f lsb' % peakerr)
    print('rms error =     %20.12f lsb rms' % rmserr)

    # Calculate SNR and effective number of bits.
    sinad = 20 * numpy.log10(ampl * numpy.sqrt(0.5) / rmserr)
    print('SINAD =         %12.4f dB' % sinad)
    print('ENOB =          %12.4f bits' % ((sinad - 1.76) / 6.02))

    # Determine spurious-free dynamic range.
    q = numpy.fft.rfft(dsin)
    tampl = numpy.abs(q[1])
    tspur = numpy.amax(numpy.abs(q[2:]))
    del q
    sfdr = 20 * numpy.log10(tampl / tspur)

    print('SFDR =          %12.4f dB' % sfdr)
    print()


def main():

    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        print("ERROR: Invalid/missing command line arguments", file=sys.stderr)
        sys.exit(1)

    fname = sys.argv[1]

    # Read data from file.
    print("reading", fname, "...")
    data = read_data(fname)

    print("got array", data.shape)
    print()

    # Check array shape.
    if len(data.shape) != 2 or data.shape[1] != 2:
        print("ERROR: Expected array of shape (N, 2)", file=sys.stderr)
        sys.exit(1)

    # Check number of samples.
    if data.shape[0] < 4 or (data.shape[0] & (data.shape[0] - 1)) != 0:
        print("ERROR: Expected power-of-two record length", file=sys.stderr)
        sys.exit(1)
 
    eval_sine_quality(data)


if __name__ == '__main__':
    main()

