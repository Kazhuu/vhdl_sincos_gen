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
--   not yet implemented
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_test_sincos is

    port (
        -- 100 MHz system clock
        clk:        in  std_logic;

        -- Reset button
        resetn:     in  std_logic;

        -- Status LEDs
        led:        out std_logic_vector(7 downto 0);

        -- Uart
        uartrx:     in  std_logic;
        uarttx:     out std_logic;

        -- AC97 audio
        ac97_bitclk:    in  std_logic;
        ac97_sdi:       in  std_logic;
        ac97_sdo:       out std_logic;
        ac97_sync:      out std_logic;
        ac97_rst:       out std_logic );

end entity;

architecture rtl of top_test_sincos is

    signal r_rstgen:    std_logic_vector(7 downto 0) := "00000000";
    signal r_reset:     std_logic;

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

    -- Drive unused LEDs.
    led(7 downto 4) <= "0000";

    -- AC97 not yet implemented
    ac97_sdo    <= '0';
    ac97_sync   <= '0';
    ac97_rst    <= '0';

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

end architecture;

