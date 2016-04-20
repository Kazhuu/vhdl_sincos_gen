--
--  Wrapper for sine / cosine function core
--
--  Copyright 2016 Joris van Rantwijk
--
--  This design is free software; you can redistribute it and/or
--  modify it under the terms of the GNU Lesser General Public
--  License as published by the Free Software Foundation; either
--  version 2.1 of the License, or (at your option) any later version.
--
--
--  Phase input:
--    unsigned 26 bits (2**26 steps for a full circle)
--
--  Sin/cos output:
--    signed 24 bits (nominal amplitude = 2**23-1)
--
--  Latency:
--    9 clock cycles
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sincos_gen_d24_p26 is

    port (
        -- System clock, active on rising edge.
        clk:        in  std_logic;

        -- Clock enable.
        clk_en:     in  std_logic;

        -- Phase input.
        in_phase:   in  unsigned(25 downto 0);

        -- Sine output.
        -- (9 clock cycles latency after in_phase).
        out_sin:    out signed(23 downto 0);

        -- Cosine output.
        -- (9 clock cycles latency after in_phase).
        out_cos:    out signed(23 downto 0) );

end entity;

architecture rtl of sincos_gen_d24_p26 is

begin

    gen0: entity work.sincos_gen
        generic map (
            data_bits       => 24,
            phase_bits      => 26,
            phase_extrabits => 2,
            table_addrbits  => 10,
            taylor_order    => 2 )
        port map (
            clk             => clk,
            clk_en          => clk_en,
            in_phase        => in_phase,
            out_sin         => out_sin,
            out_cos         => out_cos );

end architecture;
