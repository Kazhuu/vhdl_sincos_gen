--
-- Test sine / cosine function core on Digilent Atlys board.
--
--
-- Serial port protocol (via USB):
--
--   * Baud rate 115200
--
--   * Send 6 bytes
--       { 0x41 0x42 phase(7:0) phase(15:8) phase(23:16) phase(31:24) }
--     to calculate sine and cosine of phase on the 18-bit / 20-bit core.
--     Board answers with 8 bytes
--       { sin(7:0) sin(15:8) sin(23:16) sin(31:24)
--         cos(7:0) cos(15:8) cos(23:16) cos(31:24 }
--
--   * Send 6 bytes
--       { 0x41 0x43 phase(7:0) phase(15:8) phase(23:16) phase(31:24) }
--     to calculate sine and cosine of phase on the 24-bit / 26-bit core.
--     Board answers with 8 bytes
--       { sin(7:0) sin(15:8) sin(23:16) sin(31:24)
--         cos(7:0) cos(15:8) cos(23:16) cos(31:24 }
--
--   * Send 2 bytes { 0x41 0x44 } to start clock-enable modulation.
--
--   * Send 3 bytes { 0x41 0x45 } to stop clock-enable modulation.
--
-- Status LEDs:
--   LED 0    = Ready (waiting for command)
--   LED 1    = Calculating
--   LED 2    = Clock-enable modulation active
--   LED 3    = Transmitting
--
-- AC97 audio:
--   999.985 Hz sine wave on output
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_test_sincos is

    port (
        -- 100 MHz system clock
        clk:            in  std_logic;

        -- Reset button
        resetn:         in  std_logic;

        -- Status LEDs
        led:            out std_logic_vector(7 downto 0);

        -- Uart
        uartrx:         in  std_logic;
        uarttx:         out std_logic;

        -- AC97 audio
        ac97_bitclk:    in  std_logic;
        ac97_sdi:       in  std_logic;
        ac97_sdo:       out std_logic;
        ac97_sync:      out std_logic;
        ac97_rst:       out std_logic );

end entity;

architecture rtl of top_test_sincos is

    -- Frequency is 21845 / 2**20 * 48000 Hz = 999.985 Hz
    constant tone_freq: integer := 21845;

    signal r_rstgen:    std_logic_vector(7 downto 0) := "00000000";
    signal r_reset:     std_logic;

    signal r_ac97_rstcnt: unsigned(7 downto 0);
    signal r_ac97_rst:   std_logic;
    signal r_ac97_rstsync: std_logic_vector(7 downto 0);
    signal r_ac97_phase: unsigned(19 downto 0);
    signal s_ac97_sine:  signed(17 downto 0);
    signal s_ac97_dataleft:  signed(19 downto 0);
    signal s_ac97_dataright: signed(19 downto 0);
    signal s_ac97_ready: std_logic;

begin

    -- Instantiate test design with serial interface.
    u0: entity work.test_sincos_serial
        generic map (
            serial_bitrate_divider => 868 )
        port map (
            clk         => clk,
            rst         => r_reset,
            ser_rx      => uartrx,
            ser_tx      => uarttx,
            stat_ready  => led(0),
            stat_calc   => led(1),
            stat_clkmod => led(2),
            stat_txser  => led(3) );

    -- Instantiate sine generator for AC97 output.
    u1: entity work.sincos_gen_d18_p20
        port map (
            clk         => ac97_bitclk,
            clk_en      => '1',
            in_phase    => r_ac97_phase,
            out_sin     => s_ac97_sine,
            out_cos     => open );

    -- Instantiate AC97 output 
    u2: entity work.ac97out
        port map (
            bitclk      => ac97_bitclk,
            rst         => r_ac97_rstsync(0),
            data_left   => s_ac97_dataleft,
            data_right  => s_ac97_dataright,
            data_valid  => '1',
            data_ready  => s_ac97_ready,
            ac97_sdo    => ac97_sdo,
            ac97_sync   => ac97_sync );

    s_ac97_dataleft  <= s_ac97_sine & "00";
    s_ac97_dataright <= s_ac97_sine & "00";

    -- Drive unused LEDs.
    led(7 downto 4) <= "0000";

    -- Drive AC97 reset pin.
    ac97_rst    <= r_ac97_rst;

    -- Reset synchronizer.
    process (clk) is
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                r_rstgen    <= (others => '0');
                r_reset     <= '1';
            else
                r_rstgen    <= "1" & r_rstgen(7 downto 1);
                r_reset     <= not r_rstgen(0);
            end if;
        end if;
    end process;

    -- Reset generator for AC97 codec.
    process (clk) is
    begin
        if rising_edge(clk) then
            if r_reset = '1' then
                r_ac97_rstcnt   <= (others => '1');
                r_ac97_rst      <= '0';
            else
                r_ac97_rstcnt   <= r_ac97_rstcnt - 1;
                if r_ac97_rstcnt = 0 then
                    r_ac97_rst      <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Synchronous process in AC97 bitclock domain.
    process (ac97_bitclk, r_ac97_rst) is
    begin
        if r_ac97_rst = '0' then
            r_ac97_rstsync  <= (others => '1');
            r_ac97_phase    <= (others => '0');
        elsif rising_edge(ac97_bitclk) then
            r_ac97_rstsync  <= "0" & r_ac97_rstsync(7 downto 1);
            if s_ac97_ready = '1' then
                r_ac97_phase <= r_ac97_phase + tone_freq;
            end if;
        end if;
    end process;

end architecture;

