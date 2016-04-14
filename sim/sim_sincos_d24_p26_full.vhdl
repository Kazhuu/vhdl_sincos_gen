--
-- Top-level simulation test bench to test sincos_gen_d24_p26
-- for all possible inputs.
--
-- Joris van Rantwijk
--

library std;
use std.textio.all;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sim_sincos_d24_p26_full is

end entity;

architecture arch of sim_sincos_d24_p26_full is

    constant latency: integer := 9;
    constant phaserange: integer := 2**26;

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
        constant strspace: string := " ";
        file outf: text is out "sim_sincos_d24_p26_full.dat";
        variable lin: line;
    begin

        clk_enable  <= true;
        clk_en      <= '0';
        in_phase    <= (others => '0');
        
        wait until falling_edge(clk);
        wait until falling_edge(clk);

        clk_en      <= '1';

        -- Test at all possible inputs.
        for p in 0 to phaserange+latency loop

            in_phase <= to_unsigned(p, 26);

            if p >= latency and p < phaserange+latency then
                write(lin, to_integer(out_sin));
                write(lin, strspace);
                write(lin, to_integer(out_cos));
                writeline(outf, lin);               
            end if;

            wait until falling_edge(clk);

        end loop;

        clk_enable  <= false;
        wait;

    end process;

end arch;
