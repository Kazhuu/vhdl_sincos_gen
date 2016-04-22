--
-- Simple core for AC97 audio output.
-- Only tested with LM4550 on Digilent Atlys board.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ac97out is

    port (
        -- AC97 bit clock.
        bitclk:     in  std_logic;

        -- Synchronous reset, active high.
        rst:        in  std_logic;

        -- Input samples for left and right channel.
        data_left:  in  signed(19 downto 0);
        data_right: in  signed(19 downto 0);

        -- Data handshake.
        data_valid: in  std_logic;
        data_ready: out std_logic;

        -- AC97 interface signals.
        ac97_sdo:   out std_logic;
        ac97_sync:  out std_logic );

end entity;

architecture rtl of ac97out is

    -- Initialization sequence.
    type init_table_type is array(0 to 7) of std_logic_vector(23 downto 0);
    constant init_table: init_table_type := (
        -- write 0x0000 to register 0x00: soft reset
        x"000000",
        -- write 0x0000 to register 0x02: set master volume to maximum 
        x"020000",
        -- write 0x0000 to register 0x04: set headphone volume to maximum
        x"040000",
        -- write 0x0000 to register 0x06: set mono_out volume to maximum
        x"060000",
        -- write 0x0808 to register 0x18: set PCM out volume to 0 dB
        x"180808",
        -- dummy read from register 0x00
        x"800000",
        x"800000",
        x"800000" );

    -- Output registers.
    signal r_sdo:       std_logic;
    signal r_sync:      std_logic;

    -- Bit counter.
    signal r_bitcnt:    unsigned(7 downto 0);
    signal r_lastbit:   std_logic;
    signal r_firstbit:  std_logic;

    -- Initialization state machine.
    signal r_initdone:  std_logic;
    signal r_initstep:  unsigned(2 downto 0);
    signal r_initword:  std_logic_vector(23 downto 0);

    -- Data for next frame.
    signal r_datavalid: std_logic;
    signal r_dataleft:  std_logic_vector(19 downto 0);
    signal r_dataright: std_logic_vector(19 downto 0);

    -- Frame data shift register (tag + slots 1 .. 4)
    signal r_sdoshift:  std_logic_vector(95 downto 0);

begin

    -- Drive outputs.
    data_ready  <= not r_datavalid;
    ac97_sdo    <= r_sdo;
    ac97_sync   <= r_sync;

    -- Synchronous process.
    process (bitclk) is
    begin
        if rising_edge(bitclk) then

            -- Drive SYNC high on first bit of frame.
            r_sync      <= r_firstbit;

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
                r_sdoshift(94)  <= not r_initdone;
                r_sdoshift(93)  <= not r_initdone;

                -- Set slots 3 and 4 valid if we have valid data.
                r_sdoshift(92)  <= r_datavalid;
                r_sdoshift(91)  <= r_datavalid;

                -- Remaining tag bits always zero.
                r_sdoshift(90 downto 80) <= (others => '0');

                -- Slot 1: Register read/write command.
                -- bit 19 = read (1) or write (0)
                -- bit 18:12 = address
                r_sdoshift(79 downto 72) <= r_initword(23 downto 16);
                r_sdoshift(71 downto 0) <= (others => '0');

                -- Slot 2: Register write data.
                -- bit 19:4 = data
                r_sdoshift(59 downto 44) <= r_initword(15 downto 0);
                r_sdoshift(43 downto 40) <= (others => '0');

                -- Update init pointer.
                r_initstep      <= r_initstep + 1;
                if r_initstep = 7 then
                    r_initdone      <= '1';
                end if;

                -- Slots 3 and 4: left and right sample value.
                r_sdoshift(39 downto 20) <= r_dataleft;
                r_sdoshift(19 downto  0) <= r_dataright;

                -- Consume sample values.
                r_datavalid     <= '0';

            end if;

            -- Update bit counter.
            r_bitcnt    <= r_bitcnt - 1;
            r_firstbit  <= r_lastbit;
            if r_bitcnt = 1 then
                r_lastbit   <= '1';
            else
                r_lastbit   <= '0';
            end if;

            -- Capture input data.
            if r_datavalid = '0' and data_valid = '1' then
                r_datavalid <= '1';
                r_dataleft  <= std_logic_vector(data_left);
                r_dataright <= std_logic_vector(data_right);
            end if;

            -- Synchronous reset.
            if rst = '1' then
                r_initdone  <= '0';
                r_initstep  <= (others => '0');
                r_bitcnt    <= (others => '0');
                r_firstbit  <= '0';
                r_datavalid <= '0';
            end if;

        end if;
    end process;

end architecture;

