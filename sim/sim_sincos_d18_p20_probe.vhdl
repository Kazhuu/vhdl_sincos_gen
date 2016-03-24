--
-- Top-level simulation test bench to probe sincos_gen_d18_p20
-- at a couple of test inputs.
--
-- Joris van Rantwijk
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sim_sincos_d18_p20_probe is

end entity;

architecture arch of sim_sincos_d18_p20_probe is

    type input_list_type is array(natural range <>) of integer;
    constant input_list: input_list_type(0 to 7) := (
        0,          -- 0 rad
        12345,      -- 0.073972 rad
        131072,     -- 45 degrees
        166886,     -- 0.999999 rad
        262144,     -- 90 degrees
        345678,     -- 2.071341 rad
        667544,     -- 3.999999 rad
        1019449 );  -- 350.0000 degrees

    signal clk_enable:  boolean := false;
    signal clk:         std_logic;
    signal clk_en:      std_logic;
    signal in_phase:    unsigned(19 downto 0);
    signal out_sin:     signed(17 downto 0);
    signal out_cos:     signed(17 downto 0);

begin

    clk <= (not clk) after 2 ns when clk_enable else '0';

    gen0: entity work.sincos_gen_d18_p20
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
        for i in 0 to 7+6 loop

            if i <= 7 then
                in_phase    <= to_unsigned(input_list(i), 20);
            end if;

            if i >= 6 then
                report "  phase=" & integer'image(input_list(i-6)) &
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
