--
--  Synthesizable design for testing the sine / cosine function core.
--
--  Copyright 2016 Joris van Rantwijk
--
--  This design is free software; you can redistribute it and/or
--  modify it under the terms of the GNU Lesser General Public
--  License as published by the Free Software Foundation; either
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_sincos_serial is

    generic (
        -- Clock frequency divider from system clock to serial bitrate.
        --   bitrate = system_clock_frequency / serial_bitrate_divider
        serial_bitrate_divider: integer range 10 to 8191;

        -- Select core.
        --   1 = 18-bit sin/cos generator;
        --   2 = 24-bit sin/cos generator.
        core_select: integer range 1 to 2 );

    port (
        -- System clock, active on rising edge.
        clk:        in  std_logic;

        -- Synchronous reset, active high.
        rst:        in  std_logic;

        -- Serial RX input.
        ser_rx:     in  std_logic;

        -- Serial TX output.
        ser_tx:     out std_logic );

end entity;

architecture rtl of test_sincos_serial is

    constant latency:       integer := 3 + 3 * core_select;

    signal r_clk_en:        std_logic;
    signal r_in_phase:      unsigned(31 downto 0);
    signal s_out_sin:       signed(31 downto 0);
    signal s_out_cos:       signed(31 downto 0);
    signal s_gen1_out_sin:  signed(17 downto 0);
    signal s_gen1_out_cos:  signed(17 downto 0);
    signal s_gen2_out_sin:  signed(23 downto 0);
    signal s_gen2_out_cos:  signed(23 downto 0);

    signal r_tst_start:     std_logic;
    signal r_tst_in_phase:  unsigned(31 downto 0);
    signal r_tst_out_sin:   unsigned(31 downto 0);
    signal r_tst_out_cos:   unsigned(31 downto 0);
    signal r_tst_busy:      std_logic;
    signal r_tst_cyclecnt:  unsigned(3 downto 0);

    signal r_clkmod:        std_logic;
    signal r_clkmod_cnt:    unsigned(3 downto 0);
    signal r_clkmod_tmp:    std_logic;

    signal r_ser_rx_strobe: std_logic;
    signal r_ser_rx_byte:   std_logic_vector(7 downto 0);

    signal r_ser_tx_strobe: std_logic;
    signal r_ser_tx_busy:   std_logic;
    signal r_ser_tx_byte:   std_logic_vector(7 downto 0);

begin

    -- Instantiate 18-bit sin/cos core.
    gen1: if core_select = 1 generate

        gen1x: entity work.sincos_gen_d18_p20
            port map (
                clk             => clk,
                clk_en          => r_clk_en,
                in_phase        => r_in_phase(19 downto 0),
                out_sin         => s_gen1_out_sin,
                out_cos         => s_gen1_out_cos );

        s_out_sin <= resize(s_gen1_out_sin, 32);
        s_out_cos <= resize(s_gen1_out_cos, 32);

    end generate;

    -- Instantiate 24-bit sin/cos core.
    gen2: if core_select = 2 generate

        gen2x: entity work.sincos_gen_d24_p26
            port map (
                clk             => clk,
                clk_en          => r_clk_en,
                in_phase        => r_in_phase(25 downto 0),
                out_sin         => s_gen2_out_sin,
                out_cos         => s_gen2_out_cos );

        s_out_sin <= resize(s_gen2_out_sin, 32);
        s_out_cos <= resize(s_gen2_out_cos, 32);

    end generate;

    -- Synchronous process.
    -- State machine for interface to design under test.
    process (clk) is
    begin
        if rising_edge(clk) then

            if r_clk_en = '1' then
                r_tst_cyclecnt  <= r_tst_cyclecnt + 1;
                r_in_phase      <= (others => '0');
            end if;

            if r_tst_busy = '1' and r_tst_cyclecnt = latency then
                r_tst_busy      <= '0';
                r_tst_out_sin   <= s_out_sin;
                r_tst_out_cos   <= s_out_cos;
            end if;

            if r_tst_start = '1' and r_tst_busy = '0' then
                r_tst_busy      <= '1';
                r_in_phase      <= r_tst_in_phase;
                r_tst_cyclecnt  <= (others => '0');
            end if;

            if rst = '1' then
                r_tst_busy      <= '0';
            end if;

        end if;
    end process;

    -- Synchronous process.
    -- Drive clk_en signal (continuous or modulated).
    process (clk) is
    begin
        if rising_edge(clk) then

            if r_clkmod = '1' then
                -- Clock-enable modulation disabled.
                r_clk_en        <= '1';
            else
                -- Clock-enable modulation active.
                r_clk_en        <= r_clkmod_tmp;
            end if;

            -- Make r_clkmod_tmp high on 5 out of 16 cycles.
            if r_clkmod_cnt = 1 or r_clkmod_cnt = 4 or r_clkmod_cnt = 5 or
               r_clkmod_cnt = 7 or r_clkmod_cnt = 12 then
                r_clkmod_tmp    <= '1';
            else
                r_clkmod_tmp    <= '0';
            end if; 
 
            r_clkmod_cnt    <= r_clkmod_cnt + 1;

            if rst = '1' then
                r_clkmod_cnt    <= (others => '0');
                r_clkmod_tmp    <= '0';
                r_clk_en        <= '1';
            end if;

        end if;
    end process;

-- TODO : byte-level protocol

-- TODO : serial port RX machine
-- TODO : serial port TX machine

end architecture;
