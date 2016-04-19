
  Sine / cosine generator in VHDL
 =================================

This package contains a sine / cosine generator in synthesizable VHDL code.

The core takes a phase value as input and produces the corresponding sine
and cosine as signed integer outputs. The core is fully pipelined, accepting
a new phase input on every clock cycle. The corresponding sine/cosine outputs
appear after a latency of 6 or 9 clock cycles (depending on configuration).

The VHDL code has been optimized for Xilinx FPGAs and is arranged
to make efficient use of block RAM and DSP primivites in Xilinx FPGAs.


  Algorithm
  ---------

The core uses a small lookup table, with interpolation between table entries
based on the Taylor series.

A lookup table contains a limited number (about 1024) points in the
first quadrant of the sine function. The following steps are performed
to compute the sine and cosine of an arbitrary point in the first quadrant:

 1) Lookup the closest phase point in the sine table. This is done
    simultaneously for the sine and cosine, using cos(x) = sin(pi/2-x).

    sin_base = table[ i ]
    cos_base = table[ M-i ]

    These two lookups are done simultaneously, using a table stored
    in a ROM block with two read ports.

 2) Compute the phase mismatch between the table point and actual
    phase input in radians. This requires multiplication by Pi,
    which is implemented through repeated shifting and adding.

 3) Use the Taylor series to obtain a more accurate approximation
    of the answer. Depending on the required accuracy, either 1st order
    or 2nd order Taylor approximation is used.

    sin_improved = sin_base + d_phase * cos_base
    cos_improved = cos_base - d_phase * sin_base

      or

    sin_improved = sin_base + d_phase * ( cos_base - d_phase * sin_base / 2)
    cos_improved = cos_base - d_phase * ( sin_base + d_phase * cos_base / 2)

    This requres two (1st order) or four (2nd order) multiply-accumulate
    steps, which are implemented in DSPs.

 4) Round the improved result to the required accuracy.

Phase points not in the first quadrant are obtained by simple mirroring,
i.e. swapping of sine and cosine and/or sign flipping based on

  sin(x+pi/2) = cos(x),   cos(x+pi/2) = -sin(x)
  sin(x+pi)   = -sin(x),  cos(x+pi)   = -cos(x)

This automatically ensures that the full sine waveform is perfectly
balanced around zero and that the 90 degree phase shift between sine
and cosine holds exactly.


  Code organization
  -----------------

The generic core implementation is only one VHDL file (sincos_gen.vhdl).
It has tunable parameters to set input/output word length and to trade
accuracy vs resources. Do not mess around with those parameters!
Detailed understanding of the algorithm is required to choose good parameters.
Incorrect parameters may make the output inaccurate or plain wrong.

Two wrappers are available which set the parameters for a sensible
balance between accuracy and efficiency:

sincos_gen_d18_p20.vhdl is for 18-bit sine/cosine output.
sincos_gen_d24_p26.vhdl is for 24-bit sine/cosine output.

These two wrappers are the only tested variants of the core.


  rtl/                          Synthesizable VHDL code
  rtl/sincos_gen.vhdl           Implementation of core with tunable generics
  rtl/sincos_gen_d18_p20.vhdl   Wrapper for 18-bit output, 20-bit phase variant
  rtl/sincos_gen_d24_p26.vhdl   Wrapper for 24-bit output, 26-bit phase variant
  rtl/test_sincos_serial.vhdl   Synthesizable test fixture for testing in FPGA

  sim/                          Test benches
  sim/Makefile                  Makefile for building test benches with GHDL
  sim/sim_sincos_*_probe.vhdl   Simulate core for a few phase inputs
  sim/sim_sincos_*_full.vhdl    Simulate core for all possible phase inputs

  tools/eval_sine_quality.py    Python program to determine accuracy of
                                output from sim_sincos_dXX_pYY_full.

  synth/                        Synthesis runs for Xilinx FPGAs.


  Output accuracy
  ---------------

Accuracy of the sine/cosine output from the cores has been determined from
a simulation of the VHDL code on all possible phase input values.

----

Core variant                 sincos_gen_d18_p20      sincos_gen_d24_p26
Phase input width                       20 bits                 26 bits
Sin/cos output width                    18 bits                 24 bits

Amplitude                     131071.008033 lsb     8388606.997478 lsb
Offset                             0.000000 lsb           0.000000 lsb
Phase mismatch                     1.30e-7  rad           1.99e-9  rad

Peak absolute error                0.966104 lsb           1.029916 lsb
Root-mean-square error             0.330982 lsb rms       0.332547 lsb rms
SINAD                            108.94     dB          145.03     dB
Effective nr of bits              17.80     bits         23.80     bits
Spurious-free dynamic range      129.81     dB          166.18     dB

cos(x) == sin(x+pi/2)               exact match            exact match
sin(x) == - sin(x+pi)               exact match            exact match

----


  FPGA resources
  --------------

----

FPGA type               Xilinx Spartan-6 LX45-3     Xilinx Virtex-7 485T-1
Synthesizer             Xilinx ISE 14.7             Xilinx Vivado 2014.4.1

Core variant            d18_p20     d24_p26         d18_p20     d24_p26

Flip-flops              134         250             151         291
LUTs                    118         204             115         181
RAMB18                    0           0               1           0
RAMB36                    0           0               0           1
DSP48E1                   0           0               2           4
RAMB16BWER                1           1
RAMB8BWER                 0           1
DSP48A1                   2           4

Clock freq              230 MHz     230 MHz         400 MHz     400 MHz

----

