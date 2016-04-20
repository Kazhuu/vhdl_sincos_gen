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
        serial_bitrate_divider: integer range 10 to 8192;

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
    signal r_tst_in_phase:  std_logic_vector(31 downto 0);
    signal r_tst_out_sin:   std_logic_vector(31 downto 0);
    signal r_tst_out_cos:   std_logic_vector(31 downto 0);
    signal r_tst_busy:      std_logic;
    signal r_tst_cyclecnt:  unsigned(3 downto 0);

    signal r_clkmod:        std_logic;
    signal r_clkmod_cnt:    unsigned(3 downto 0);
    signal r_clkmod_tmp:    std_logic;

    signal r_ctl_state:     std_logic_vector(3 downto 0);

    signal r_ser_rx_strobe: std_logic;
    signal r_ser_rx_byte:   std_logic_vector(7 downto 0);
    signal r_ser_rx_glitch: std_logic_vector(7 downto 0);
    signal r_ser_rx_bit:    std_logic;
    signal r_ser_rx_timer:  unsigned(12 downto 0);
    signal r_ser_rx_timeout: std_logic;
    signal r_ser_rx_state:  std_logic_vector(1 downto 0);
    signal r_ser_rx_shift:  std_logic_vector(8 downto 0);

    signal r_ser_tx_strobe: std_logic;
    signal r_ser_tx_busy:   std_logic;
    signal r_ser_tx_byte:   std_logic_vector(7 downto 0);
    signal r_ser_tx_bit:    std_logic;
    signal r_ser_tx_timer:  unsigned(12 downto 0);
    signal r_ser_tx_timeout: std_logic;
    signal r_ser_tx_bitcnt: unsigned(3 downto 0);
    signal r_ser_tx_shift:  std_logic_vector(7 downto 0);

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
                r_tst_out_sin   <= std_logic_vector(s_out_sin);
                r_tst_out_cos   <= std_logic_vector(s_out_cos);
            end if;

            if r_tst_start = '1' and r_tst_busy = '0' then
                r_tst_busy      <= '1';
                r_in_phase      <= unsigned(r_tst_in_phase);
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

            if r_clkmod = '0' then
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

    -- Synchronous process.
    -- Byte-level serial protocol.
    process (clk) is
    begin
        if rising_edge(clk) then

            r_ser_tx_strobe     <= '0';
            r_tst_start         <= '0';

            if r_ctl_state = "0000" and
               r_ser_rx_strobe = '1' and r_ser_rx_byte = x"41" then
                r_ctl_state     <= "0001";
            end if;

            if r_ctl_state = "0001" and r_ser_rx_strobe = '1' then
                if r_ser_rx_byte = x"42" then
                    r_ctl_state     <= "0010";
                elsif r_ser_rx_byte = x"43" then
                    r_ctl_state     <= "0000";
                    r_clkmod        <= '1';
                elsif r_ser_rx_byte = x"44" then
                    r_ctl_state     <= "0000";
                    r_clkmod        <= '0';
                else
                    r_ctl_state     <= "0000";
                end if;
            end if;

            if r_ctl_state = "0010" and r_ser_rx_strobe = '1' then
                r_ctl_state     <= "0011";
                r_tst_in_phase  <= r_ser_rx_byte & r_tst_in_phase(31 downto 8);
            end if;

            if r_ctl_state = "0011" and r_ser_rx_strobe = '1' then
                r_ctl_state     <= "0100";
                r_tst_in_phase  <= r_ser_rx_byte & r_tst_in_phase(31 downto 8);
            end if;

            if r_ctl_state = "0100" and r_ser_rx_strobe = '1' then
                r_ctl_state     <= "0101";
                r_tst_in_phase  <= r_ser_rx_byte & r_tst_in_phase(31 downto 8);
            end if;

            if r_ctl_state = "0101" and r_ser_rx_strobe = '1' then
                r_ctl_state     <= "0110";
                r_tst_in_phase  <= r_ser_rx_byte & r_tst_in_phase(31 downto 8);
                r_tst_start     <= '1';
            end if;

            if r_ctl_state = "0110" and r_tst_start = '0' and r_tst_busy = '0' then
                r_ctl_state     <= "0111";
            end if;

            if r_ctl_state = "0111" and r_ser_tx_busy = '0' then
                r_ctl_state     <= "1000";
                r_ser_tx_byte   <= r_tst_out_sin(7 downto 0);
                r_ser_tx_strobe <= '1';
            end if;

            if r_ctl_state = "1000" and r_ser_tx_strobe = '0' and r_ser_tx_busy = '0' then
                r_ctl_state     <= "1001";
                r_ser_tx_byte   <= r_tst_out_sin(15 downto 8);
                r_ser_tx_strobe <= '1';
            end if;

            if r_ctl_state = "1001" and r_ser_tx_strobe = '0' and r_ser_tx_busy = '0' then
                r_ctl_state     <= "1010";
                r_ser_tx_byte   <= r_tst_out_sin(23 downto 16);
                r_ser_tx_strobe <= '1';
            end if;

            if r_ctl_state = "1010" and r_ser_tx_strobe = '0' and r_ser_tx_busy = '0' then
                r_ctl_state     <= "1011";
                r_ser_tx_byte   <= r_tst_out_sin(31 downto 24);
                r_ser_tx_strobe <= '1';
            end if;

            if r_ctl_state = "1011" and r_ser_tx_strobe = '0' and r_ser_tx_busy = '0' then
                r_ctl_state     <= "1100";
                r_ser_tx_byte   <= r_tst_out_cos(7 downto 0);
                r_ser_tx_strobe <= '1';
            end if;

            if r_ctl_state = "1100" and r_ser_tx_strobe = '0' and r_ser_tx_busy = '0' then
                r_ctl_state     <= "1101";
                r_ser_tx_byte   <= r_tst_out_cos(15 downto 8);
                r_ser_tx_strobe <= '1';
            end if;

            if r_ctl_state = "1101" and r_ser_tx_strobe = '0' and r_ser_tx_busy = '0' then
                r_ctl_state     <= "1110";
                r_ser_tx_byte   <= r_tst_out_cos(23 downto 16);
                r_ser_tx_strobe <= '1';
            end if;

            if r_ctl_state = "1110" and r_ser_tx_strobe = '0' and r_ser_tx_busy = '0' then
                r_ctl_state     <= "0000";
                r_ser_tx_byte   <= r_tst_out_cos(31 downto 24);
                r_ser_tx_strobe <= '1';
            end if;

            -- Synchronous reset.
            if rst = '1' then
                r_ctl_state     <= "0000";
                r_clkmod        <= '0';
            end if;

        end if;
    end process;

    -- Synchronous process.
    -- Serial port RX machine.
    process (clk) is
    begin
        if rising_edge(clk) then

            -- Default.
            r_ser_rx_strobe <= '0';

            -- Deglitch filter.
            r_ser_rx_glitch <= r_ser_rx_glitch(6 downto 0) & ser_rx;
            if r_ser_rx_glitch(7 downto 1) = "0000000" then
                r_ser_rx_bit <= '0';
            elsif r_ser_rx_glitch(7 downto 1) = "1111111" then
                r_ser_rx_bit <= '1';
            end if;

            -- Bit timer.
            r_ser_rx_timer  <= r_ser_rx_timer - 1;
            if r_ser_rx_timer = 0 then
                r_ser_rx_timeout <= '1';
            else
                r_ser_rx_timeout <= '0';
            end if;

            -- RX state machine.
            if r_ser_rx_state = "00" then
                -- Wait for idle level.
                if r_ser_rx_bit = '1' then
                    r_ser_rx_state  <= "01";
                end if;
            elsif r_ser_rx_state = "01" then
                -- Wait for start of byte.
                r_ser_rx_shift(7 downto 0)  <= (others => '0');
                r_ser_rx_shift(8) <= '1';
                r_ser_rx_timer  <= to_unsigned(serial_bitrate_divider / 2 - 2, r_ser_rx_timer'length);
                r_ser_rx_timeout <= '0';
                if r_ser_rx_bit = '0' then
                    r_ser_rx_state  <= "10";
                end if;
            elsif r_ser_rx_state = "10" then
                -- Wait for data bit.
                if r_ser_rx_timeout = '1' then
                    r_ser_rx_shift  <= r_ser_rx_bit & r_ser_rx_shift(8 downto 1);
                    if r_ser_rx_shift(0) = '1' then
                        -- Reached end of byte.
                        if r_ser_rx_bit = '1' then
                            -- Got valid stop bit.
                            r_ser_rx_strobe <= '1';
                            r_ser_rx_state  <= "01";
                        else
                            -- Got invalid stop bit.
                            r_ser_rx_state  <= "00";
                        end if;
                        r_ser_rx_state  <= "11";
                    end if;
                    r_ser_rx_timer  <= to_unsigned(serial_bitrate_divider - 2, r_ser_rx_timer'length);
                end if;
            else
                -- Invalid state.
                r_ser_rx_state  <= "00";
            end if;

            -- Synchronous reset.
            if rst = '1' then
                r_ser_rx_state  <= "00";
                r_ser_rx_strobe <= '0';
            end if;

        end if;
    end process;

    -- Synchronous process.
    -- Serial port TX machine.
    process (clk) is
    begin
        if rising_edge(clk) then

            -- Drive output register.
            ser_tx      <= r_ser_tx_bit;

            -- Bit timer.
            r_ser_tx_timer  <= r_ser_tx_timer - 1;
            if r_ser_tx_timer = 0 then
                r_ser_tx_timeout <= '1';
            else
                r_ser_tx_timeout <= '0';
            end if;

            if r_ser_tx_busy = '0' then

                -- Wait for start of byte.
                r_ser_tx_timer  <= to_unsigned(serial_bitrate_divider - 2, r_ser_tx_timer'length);
                r_ser_tx_timeout <= '0';
                r_ser_tx_shift  <= r_ser_tx_byte;
                r_ser_tx_bitcnt <= to_unsigned(9, 4);
                if r_ser_tx_strobe = '1' then
                    -- Start new byte.
                    r_ser_tx_bit    <= '0';
                    r_ser_tx_busy   <= '1';
                end if;

            elsif r_ser_tx_busy = '1' and r_ser_tx_timeout = '1' then

                -- Send next bit.
                r_ser_tx_bit    <= r_ser_tx_shift(0);
                r_ser_tx_shift  <= "1" & r_ser_tx_shift(7 downto 1);
                r_ser_tx_bitcnt <= r_ser_tx_bitcnt - 1;
                r_ser_tx_timer  <= to_unsigned(serial_bitrate_divider - 2, r_ser_tx_timer'length);
                if r_ser_tx_bitcnt = 0 then
                    -- Just completed stop bit.
                    r_ser_tx_busy   <= '0';
                end if;

            end if;

            -- Synchronous reset.
            if rst = '1' then
                r_ser_tx_busy   <= '0';
                r_ser_tx_bit    <= '1';
            end if;

        end if;
    end process;

end architecture;
