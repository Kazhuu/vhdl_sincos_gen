--
--  Sine / cosine function core
--
--  Copyright 2016 Joris van Rantwijk
--
--  This design is free software; you can redistribute it and/or
--  modify it under the terms of the GNU Lesser General Public
--  License as published by the Free Software Foundation; either
--  version 2.1 of the License, or (at your option) any later version.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sincos_gen is

    generic (
        -- Number of bits in signed sin/cos output.
        -- Also number of bits in unsigned lookup table values.
        data_bits:      integer := 18;

        -- Number of bits in phase input.
        phase_bits:     integer := 20;

        -- Number of address bits for lookup table.
        table_addrbits: integer := 10;

        -- Select 1st order or 2nd order Taylor correction.
        taylor_order:   integer range 1 to 2 := 1 );

    port (
        -- System clock, active on rising edge.
        clk:        in  std_logic;

        -- Clock enable.
        clk_en:     in  std_logic;

        -- Phase input.
        in_phase:   in  unsigned(phase_bits-1 downto 0);

        -- Sine output.
        out_sin:    out signed(data_bits-1 downto 0);

        -- Cosine output.
        out_cos:    out signed(data_bits-1 downto 0) );

end entity;

architecture rtl of sincos_gen is

    -- Number of elements in lookup table.
    constant table_size:    integer := 2**table_addrbits;

    -- Number of bits in unsigned lookup table values.
    constant table_width:   integer := data_bits;

    -- Number of bits in signed delta phase term.
    constant dphase_bits:   integer := phase_bits - table_addrbits - 1;

    -- Scaling for 1st order (final) Taylor correction.
    constant accum1_bits:   integer := table_width + phase_bits - 1;
    constant round_const1:  unsigned(phase_bits-3 downto 0) := (others => '1');

    -- Scaling for 2nd order Taylor correction.
    constant accum2_bits:   integer := table_width + phase_bits;
    constant round_const2:  unsigned(phase_bits-2 downto 0) := "0" & round_const1;

    -- Lookup table type.
    type table_type is array(0 to table_size-1) of
      std_logic_vector(table_width-1 downto 0);

    -- Function to generate lookup table at synthesis time.
    function gen_table return table_type is
        variable tbl: table_type;
        variable sin_flt: real;
        variable sin_int: integer;
    begin
        for i in 0 to table_size-1 loop
            sin_flt := sin(real(2*i + 1) / real(2 * table_size) * MATH_PI / 2.0);
            sin_int := integer(sin_flt * real(2**table_width - 1));
            tbl(i) := std_logic_vector(to_unsigned(sin_int, table_width));
        end loop;
        return tbl;
    end function;

    -- Lookup table for the first quarter-period of the sine.
    -- lookup_table(i) = sin( (i + 0.5) / table_size * pi / 2 )
    constant lookup_table: table_type := gen_table;

    -- Internal registers.
    signal r1_quadrant: unsigned(1 downto 0);
    signal r1_rphase:   signed(dphase_bits-2 downto 0);
    signal r1_dphase:   signed(dphase_bits-1 downto 0);
    signal r1_sin_addr: unsigned(table_addrbits-1 downto 0);
    signal r1_cos_addr: unsigned(table_addrbits-1 downto 0);
    signal r2_quadrant: unsigned(1 downto 0);
    signal r2_rphase:   signed(dphase_bits-2 downto 0);
    signal r2_dphase:   signed(dphase_bits-1 downto 0);
    signal r2_sin_data: unsigned(table_width-1 downto 0);
    signal r2_cos_data: unsigned(table_width-1 downto 0);
    signal r3_quadrant: unsigned(1 downto 0);
    signal r3_dphase:   signed(dphase_bits-1 downto 0);
    signal r3_sin_data: unsigned(table_width-1 downto 0);
    signal r3_cos_data: unsigned(table_width-1 downto 0);
    signal r3_sinm2_a:  signed(table_width downto 0);
    signal r3_sinm2_b:  signed(dphase_bits-1 downto 0);
    signal r3_cosm2_a:  signed(table_width downto 0);
    signal r3_cosm2_b:  signed(dphase_bits-1 downto 0);
    signal r4_quadrant: unsigned(1 downto 0);
    signal r4_dphase:   signed(dphase_bits-1 downto 0);
    signal r4_sin_data: unsigned(table_width-1 downto 0);
    signal r4_cos_data: unsigned(table_width-1 downto 0);
    signal r4_sinm2_m:  signed(table_width+dphase_bits downto 0);
    signal r4_sinm2_c:  signed(accum2_bits-1 downto 0);
    signal r4_cosm2_m:  signed(table_width+dphase_bits downto 0);
    signal r4_cosm2_c:  signed(accum2_bits-1 downto 0);
    signal r5_quadrant: unsigned(1 downto 0);
    signal r5_dphase:   signed(dphase_bits-1 downto 0);
    signal r5_sin_data: unsigned(table_width-1 downto 0);
    signal r5_cos_data: unsigned(table_width-1 downto 0);
    signal r5_sinm2_p:  signed(accum2_bits-1 downto 0);
    signal r5_cosm2_p:  signed(accum2_bits-1 downto 0);
    signal r6_quadrant: unsigned(1 downto 0);
    signal r6_sin_data: unsigned(table_width-1 downto 0);
    signal r6_cos_data: unsigned(table_width-1 downto 0);
    signal r6_sinm1_a:  signed(table_width downto 0);
    signal r6_sinm1_b:  signed(dphase_bits-1 downto 0);
    signal r6_cosm1_a:  signed(table_width downto 0);
    signal r6_cosm1_b:  signed(dphase_bits-1 downto 0);
    signal r7_quadrant: unsigned(1 downto 0);
    signal r7_sinm1_m:  signed(table_width+dphase_bits downto 0);
    signal r7_sinm1_c:  signed(accum1_bits-1 downto 0);
    signal r7_cosm1_m:  signed(table_width+dphase_bits downto 0);
    signal r7_cosm1_c:  signed(accum1_bits-1 downto 0);
    signal r8_quadrant: unsigned(1 downto 0);
    signal r8_sinm1_p:  signed(accum1_bits-1 downto 0);
    signal r8_cosm1_p:  signed(accum1_bits-1 downto 0);
    signal r8_sin_neg:  std_logic;
    signal r8_cos_neg:  std_logic;

    -- Output registers.
    signal r_outsin:    signed(data_bits-1 downto 0);
    signal r_outcos:    signed(data_bits-1 downto 0);

begin

    -- Drive output ports.
    out_sin     <= r_outsin;
    out_cos     <= r_outcos;

    -- Synchronous process.
    process (clk) is
        variable v1_rphase:  signed(dphase_bits-2 downto 0);
        variable v3_dphase:  signed(dphase_bits-1 downto 0);
        variable v9_sin_val: signed(data_bits-1 downto 0);
        variable v9_cos_val: signed(data_bits-1 downto 0);
        variable v9_sin_mag: signed(data_bits-1 downto 0);
        variable v9_cos_mag: signed(data_bits-1 downto 0);
    begin
        if rising_edge(clk) then

            if clk_en = '1' then

                -- Stage 1

                -- Keep quadrant for later use.
                r1_quadrant <= in_phase(phase_bits-1 downto phase_bits-2);

                -- Extract phase remainder as signed number.
                v1_rphase(dphase_bits-2) := not in_phase(dphase_bits-2);
                v1_rphase(dphase_bits-3 downto 0) := signed(in_phase(dphase_bits-3 downto 0));

                -- Keep phase remainder and work on multiplication by Pi/2.
                r1_rphase   <= v1_rphase;
                r1_dphase   <= resize(v1_rphase, dphase_bits) +
                               resize(v1_rphase(dphase_bits-2 downto 4), dphase_bits) +
                               signed("0" & v1_rphase(3 downto 3));

                -- Extract table index for sin and cos.
                r1_sin_addr <= in_phase(phase_bits-3 downto
                                        phase_bits-2-table_addrbits);
                r1_cos_addr <= not in_phase(phase_bits-3 downto
                                            phase_bits-2-table_addrbits);

                -- Stage 2

                -- Keep quadrant for later use.
                r2_quadrant <= r1_quadrant;

                -- Keep phase remainder and work on multiplication by Pi/2.
                r2_rphase   <= r1_rphase;
                r2_dphase   <= r1_dphase +
                               resize(r1_dphase(dphase_bits-1 downto 6), dphase_bits) +
                               signed("0" & r1_dphase(5 downto 5));

                -- Table lookup.
                r2_sin_data <= unsigned(lookup_table(to_integer(r1_sin_addr)));
                r2_cos_data <= unsigned(lookup_table(to_integer(r1_cos_addr)));

                -- Stage 3

                -- Finalize multiplication of phase remainder by Pi/2.
                v3_dphase   := r2_dphase +
                               resize(r2_rphase(dphase_bits-2 downto 1), dphase_bits);

                if taylor_order = 2 then
                    -- Handle 2nd order Taylor correction.

                    -- Stage 3

                    -- Keep quadrant and delta phase for later use.
                    r3_quadrant <= r2_quadrant;
                    r3_dphase   <= v3_dphase;

                    -- Keep sin/cos table values for later use.
                    r3_sin_data <= r2_sin_data;
                    r3_cos_data <= r2_cos_data;

                    -- Prepare multiplication for 2nd order Taylor correction.
                    r3_sinm2_a  <= signed(resize(r2_sin_data, table_width+1));
                    r3_sinm2_b  <= v3_dphase;
                    r3_cosm2_a  <= signed(resize(r2_cos_data, table_width+1));
                    r3_cosm2_b  <= v3_dphase;

                    -- Stage 4

                    -- Keep quadrant and delta phase for later use.
                    r4_quadrant <= r3_quadrant;
                    r4_dphase   <= r3_dphase;

                    -- Keep sin/cos table values for later use.
                    r4_sin_data <= r3_sin_data;
                    r4_cos_data <= r3_cos_data;

                    -- Multiplication for 2nd order Taylor correction.
                    r4_sinm2_m  <= r3_sinm2_a * r3_sinm2_b;
                    r4_cosm2_m  <= r3_cosm2_a * r3_cosm2_b;

                    -- Prepare to add Taylor correction to base value.
                    -- Add a rounding constant.
                    r4_sinm2_c  <= signed(resize(r3_cos_data & round_const2, accum2_bits));
                    r4_cosm2_c  <= signed(resize(r3_sin_data & round_const2, accum2_bits));

                    -- Stage 5

                    -- Keep quadrant and delta phase for later use.
                    r5_quadrant <= r4_quadrant;
                    r5_dphase   <= r4_dphase;

                    -- Keep sin/cos table values for later use.
                    r5_sin_data <= r4_sin_data;
                    r5_cos_data <= r4_cos_data;

                    -- Add Taylor correction to base value.
                    r5_sinm2_p  <= r4_sinm2_c - resize(r4_sinm2_m, accum2_bits);
                    r5_cosm2_p  <= r4_cosm2_c + resize(r4_cosm2_m, accum2_bits);

                    -- Stage 6

                    -- Keep quadrant for later use.
                    r6_quadrant <= r5_quadrant;

                    -- Keep sin/cos table value for later use.
                    r6_sin_data <= r5_sin_data;
                    r6_cos_data <= r5_cos_data;

                    -- Prepare multiplication for 1st order Taylor correction.
                    r6_sinm1_a  <= r5_sinm2_p(accum2_bits-1 downto phase_bits-1);
                    r6_sinm1_b  <= r5_dphase;
                    r6_cosm1_a  <= r5_cosm2_p(accum2_bits-1 downto phase_bits-1);
                    r6_cosm1_b  <= r5_dphase;

                else
                    -- Only 1st order Taylor correction.

                    -- Stage 6 (skip stages 3, 4, 5)

                    -- Keep quadrant for later use.
                    r6_quadrant <= r2_quadrant;

                    -- Keep sin/cos table value for later use.
                    r6_sin_data <= r2_sin_data;
                    r6_cos_data <= r2_cos_data;

                    -- Prepare multiplication for 1st order Taylor correction.
                    r6_sinm1_a  <= signed(resize(r2_cos_data, table_width+1));
                    r6_sinm1_b  <= v3_dphase;
                    r6_cosm1_a  <= signed(resize(r2_sin_data, table_width+1));
                    r6_cosm1_b  <= v3_dphase;

                end if;

                -- Stage 7

                -- Keep quadrant for later use.
                r7_quadrant <= r6_quadrant;

                -- Multiplication for 1st order Taylor correction.
                r7_sinm1_m  <= r6_sinm1_a * r6_sinm1_b;
                r7_cosm1_m  <= r6_cosm1_a * r6_cosm1_b;

                -- Prepare to add Taylor correction to base value.
                -- Add a rounding constant.
                r7_sinm1_c  <= signed(resize(r6_sin_data & round_const1, accum1_bits));
                r7_cosm1_c  <= signed(resize(r6_cos_data & round_const1, accum1_bits));

                -- Stage 8

                -- Keep quadrant for later use.
                r8_quadrant <= r7_quadrant;

                -- Add Taylor correction to base value.
                r8_sinm1_p  <= r7_sinm1_c + resize(r7_sinm1_m, accum1_bits);
                r8_cosm1_p  <= r7_cosm1_c - resize(r7_cosm1_m, accum1_bits);

                -- Decide positive/negative value based on quadrant.
                r8_sin_neg  <= r7_quadrant(1);
                r8_cos_neg  <= r7_quadrant(0) xor r7_quadrant(1);

                -- Stage 9

                -- Extract relevant bits of answer.
                v9_sin_val  := r8_sinm1_p(accum1_bits-1 downto phase_bits-1);
                v9_cos_val  := r8_cosm1_p(accum1_bits-1 downto phase_bits-1);

                -- Choose between sin/cos based on quadrant.
                if r8_quadrant(0) = '0' then
                    v9_sin_mag  := v9_sin_val;
                    v9_cos_mag  := v9_cos_val;
                else
                    v9_sin_mag  := v9_cos_val;
                    v9_cos_mag  := v9_sin_val;
                end if;

                -- Choose positive/negative value based on quadrant.
                if r8_sin_neg = '0' then
                    r_outsin    <= 0 + v9_sin_mag;
                else
                    r_outsin    <= 0 - v9_sin_mag;
                end if;

                if r8_cos_neg = '0' then
                    r_outcos    <= 0 + v9_cos_mag;
                else
                    r_outcos    <= 0 - v9_cos_mag;
                end if;

            end if;
        end if;
    end process;

end architecture;
