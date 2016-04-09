
GHDL = ghdl
GHDLFLAGS =

.PHONY: all
all: sim_sincos_d18_p20_probe sim_sincos_d18_p20_full

sim_sincos_d18_p20_probe: sim_sincos_d18_p20_probe.o sincos_gen_d18_p20.o sincos_gen.o
sim_sincos_d18_p20_probe.o: sim_sincos_d18_p20_probe.vhdl sincos_gen_d18_p20.o

sim_sincos_d18_p20_full: sim_sincos_d18_p20_full.o sincos_gen_d18_p20.o sincos_gen.o
sim_sincos_d18_p20_full.o: sim_sincos_d18_p20_full.vhdl sincos_gen_d18_p20.o

sincos_gen.o: ../rtl/sincos_gen.vhdl
sincos_gen_d18_p20.o: ../rtl/sincos_gen_d18_p20.vhdl sincos_gen.o

sim_%: sim_%.o
	$(GHDL) $(GHDLFLAGS) -e $@

%.o: ../rtl/%.vhdl
	$(GHDL) $(GHDLFLAGS) -a $<

%.o: %.vhdl
	$(GHDL) $(GHDLFLAGS) -a $<

.PHONY: clean
clean:
	$(GHDL) --remove

