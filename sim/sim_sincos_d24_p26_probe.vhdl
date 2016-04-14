--
-- Top-level simulation test bench to probe sincos_gen_d24_p26
-- at a couple of test inputs.
--
-- Joris van Rantwijk
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sim_sincos_d24_p26_probe is

end entity;

architecture arch of sim_sincos_d24_p26_probe is

    type input_list_type is array(natural range <>) of integer;
    constant input_list: input_list_type(0 to 9) := (
        0,          -- 0 rad
        12345,      -- 0.00115582 rad
        1234567,    -- 0.11558850 rad
        8388608,    -- 45 degrees
        10680707,   -- 0.99999996 rad
        16777216,   -- 90 degrees
        20304050,   -- 1.90100236 rad
        34567890,   -- 3.23647944 rad
        42722830,   -- 4.00000003 rad
        65244729 ); -- 350.000001 degrees

    signal clk_enable:  boolean := false;
    signal clk:         std_logic;
    signal clk_en:      std_logic;
    signal in_phase:    unsigned(25 downto 0);
    signal out_sin:     signed(23 downto 0);
    signal out_cos:     signed(23 downto 0);

begin

    clk <= (not clk) after 2 ns when clk_enable else '0';

    gen0: entity work.sincos_gen_d24_p26
        port map (
            clk         => clk,
            clk_en      => clk_en,
            in_phase    => in_phase,
            out_sin     => out_sin,
            out_cos     => out_cos );

    process is
    begin

        clk_enable  <= true;
        clk_en      <= '0';
        in_phase    <= (others => '0');
        
        wait until falling_edge(clk);
        wait until falling_edge(clk);

        clk_en      <= '1';

        -- Probe at a few different inputs.
        for i in 0 to input_list'high+9 loop

            if i <= input_list'high then
                in_phase    <= to_unsigned(input_list(i), 26);
            end if;

            if i >= 9 then
                report "  phase=" & integer'image(input_list(i-9)) &
                       " sin=" & integer'image(to_integer(out_sin)) &
                       " cos=" & integer'image(to_integer(out_cos));
            end if;

            wait until falling_edge(clk);

        end loop;

        clk_en      <= '0';
        wait until falling_edge(clk);
        wait until falling_edge(clk);

        clk_enable  <= false;
        wait;

    end process;

end arch;
