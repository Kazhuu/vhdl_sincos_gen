--
-- Simple core for AC97 audio output.
--
-- Sets output volume to -12 dB,
-- then plays stereo PCM data at 48 kHz sample rate.
-- Only tested with LM4550 on Digilent Atlys board.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ac97out is

    port (
        -- AC97 bit clock.
        bitclk:     in  std_logic;

        -- Asynchronous reset, active low.
        resetn:     in  std_logic;

        -- Input samples for left and right channel.
        data_left:  in  signed(19 downto 0);
        data_right: in  signed(19 downto 0);

        -- Data handshake.
        data_valid: in  std_logic;
        data_ready: out std_logic;

        -- AC97 interface signals.
        ac97_sdi:   in  std_logic;
        ac97_sdo:   out std_logic;
        ac97_sync:  out std_logic );

end entity;

architecture rtl of ac97out is

    -- Initialization sequence.
    type init_table_type is array(0 to 7) of std_logic_vector(23 downto 0);
    constant init_table: init_table_type := (
        -- write 0x0000 to register 0x00: soft reset
        x"000000",
        -- write 0x0000 to register 0x02: set master volume to -12 dB
        x"020808",
        -- write 0x0000 to register 0x04: set headphone volume to -12 dB
        x"040808",
        -- write 0x0000 to register 0x06: set mono_out volume to -12 dB
        x"060008",
        -- write 0x0808 to register 0x18: set PCM out volume to 0 dB
        x"180808",
        -- dummy read from register 0x00
        x"800000",
        x"800000",
        x"800000" );

    -- Output registers.
    signal r_ready:     std_logic;
    signal r_sdo:       std_logic;
    signal r_sync:      std_logic;

    -- Reset synchronization.
    signal r_rstsync:   std_logic_vector(7 downto 0);

    -- Bit counter.
    signal r_bitcnt:    unsigned(7 downto 0);
    signal r_lastbit:   std_logic;
    signal r_endsync:   std_logic;

    -- Initialization state machine.
    signal r_initwait:  unsigned(5 downto 0);
    signal r_initbusy:  std_logic;
    signal r_initdone:  std_logic;
    signal r_initstep:  unsigned(2 downto 0);
    signal r_initword:  std_logic_vector(23 downto 0);

    -- Data for next frame.
    signal r_datavalid: std_logic;
    signal r_dataleft:  std_logic_vector(19 downto 0);
    signal r_dataright: std_logic_vector(19 downto 0);

    -- Frame data shift register (tag + slots 1 .. 4)
    signal r_sdoshift:  std_logic_vector(95 downto 0);

    -- AC97 bit input register
    signal r_sdi:       std_logic;

begin

    -- Drive outputs.
    data_ready  <= r_ready;
    ac97_sdo    <= r_sdo;
    ac97_sync   <= r_sync;

    -- Synchronous process.
    -- Sample AC97_SDI on falling edge of BITCLK.
    process (bitclk) is
    begin
        if falling_edge(bitclk) then
            r_sdi       <= ac97_sdi;
        end if;
    end process;

    -- Synchronous process.
    process (bitclk, resetn) is
    begin
        if resetn = '0' then

            -- Asynchronous reset.
            r_rstsync   <= (others => '0');
            r_ready     <= '0';

            -- Outputs to codec must be low during reset.
            r_sdo       <= '0';
            r_sync      <= '0';

        elsif rising_edge(bitclk) then

            -- Drive SYNC high for 16 cycles at start of frame.
            if r_lastbit = '1' then
                r_sync      <= '1';
            elsif r_endsync = '1' then
                r_sync      <= '0';
            end if;

            -- Push next data bit to output.
            r_sdo       <= r_sdoshift(r_sdoshift'high);
            r_sdoshift  <= r_sdoshift(r_sdoshift'high-1 downto 0) & "0";

            -- Fetch data from init table.
            r_initword  <= init_table(to_integer(r_initstep));

            -- Prepare next frame.
            if r_lastbit = '1' then

                -- sdoshift(95:80) = TAG
                -- bit 15 = master valid bit
                -- bit 14 = slot 1 valid
                -- bit 13 = slot 2 valid
                -- bit 12 = slot 3 valid
                -- bit 11 = slot 4 valid

                -- Always set frame valid.
                r_sdoshift(95)  <= '1';

                -- Set slots 1 and 2 valid if we are initializing.
                r_sdoshift(94)  <= r_initbusy;
                r_sdoshift(93)  <= r_initbusy;

                -- Set slots 3 and 4 valid if we have valid data.
                r_sdoshift(92)  <= r_datavalid;
                r_sdoshift(91)  <= r_datavalid;

                -- Remaining tag bits always zero.
                r_sdoshift(90 downto 80) <= (others => '0');

                -- Slot 1: Register read/write command.
                -- bit 19 = read (1) or write (0)
                -- bit 18:12 = address
                r_sdoshift(79 downto 72) <= r_initword(23 downto 16);
                r_sdoshift(71 downto 60) <= (others => '0');

                -- Slot 2: Register write data.
                -- bit 19:4 = data
                r_sdoshift(59 downto 44) <= r_initword(15 downto 0);
                r_sdoshift(43 downto 40) <= (others => '0');

                -- Update init pointer.
                if r_initbusy = '1' then
                    r_initstep      <= r_initstep + 1;
                end if;
                if r_initstep = 7 then
                    r_initbusy      <= '0';
                    r_initdone      <= '1';
                end if;

                -- Update init delay counter (wait for 1.3 ms after reset).
                r_initwait      <= r_initwait - 1;
                if r_initwait = 0 then
                    r_initstep      <= (others => '0');
                    r_initbusy      <= not r_initdone;
                end if;

                -- Slots 3 and 4: left and right sample value.
                r_sdoshift(39 downto 20) <= r_dataleft;
                r_sdoshift(19 downto  0) <= r_dataright;

                -- Consume sample values.
                r_datavalid     <= '0';
                r_ready         <= '1';

            end if;

            -- Update bit counter.
            r_bitcnt    <= r_bitcnt - 1;
            if r_bitcnt = 1 then
                r_lastbit   <= '1';
            else
                r_lastbit   <= '0';
            end if;
            if r_bitcnt = 241 then
                r_endsync   <= '1';
            else
                r_endsync   <= '0';
            end if;

            -- Capture input data.
            if r_ready = '1' and data_valid = '1' then
                r_ready     <= '0';
                r_datavalid <= '1';
                r_dataleft  <= std_logic_vector(data_left);
                r_dataright <= std_logic_vector(data_right);
            end if;

            -- Release synchronous reset.
            r_rstsync   <= "1" & r_rstsync(7 downto 1);

            -- Synchronous reset.
            if r_rstsync(0) = '0' then
                r_ready     <= '0';
                r_sdo       <= '0';
                r_sync      <= '0';
                r_initbusy  <= '0';
                r_initdone  <= '0';
                r_initwait  <= (others => '1');
                r_initstep  <= (others => '0');
                r_bitcnt    <= (others => '0');
                r_datavalid <= '0';
            end if;

        end if;
    end process;

end architecture;

