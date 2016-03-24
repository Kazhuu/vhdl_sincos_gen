
GHDL = ghdl
GHDLFLAGS =

.PHONY: all
all: sim_sincos_d18_p20_probe

sim_sincos_d18_p20_probe: sim_sincos_d18_p20_probe.o sincos_gen_d18_p20.o sincos_gen.o
	$(GHDL) $(GHDLFLAGS) -e $@

sincos_gen.o: ../rtl/sincos_gen.vhdl
	$(GHDL) $(GHDLFLAGS) -a $<

sincos_gen_d18_p20.o: ../rtl/sincos_gen_d18_p20.vhdl sincos_gen.o
	$(GHDL) $(GHDLFLAGS) -a $<

sim_sincos_d18_p20_probe.o: sim_sincos_d18_p20_probe.vhdl sincos_gen_d18_p20.o
	$(GHDL) $(GHDLFLAGS) -a $<

.PHONY: clean
clean:
	$(GHDL) --remove

