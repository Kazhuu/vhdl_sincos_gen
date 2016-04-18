--
--  Top-level design for synthesis dry-run of the sine / cosine function core.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_d18_p20 is
    port (
        clk:        in  std_logic;
        clk_en:     in  std_logic;
        in_phase:   in  std_logic_vector(19 downto 0);
        out_sin:    out std_logic_vector(17 downto 0);
        out_cos:    out std_logic_vector(17 downto 0) );
end entity;

architecture rtl of top_d18_p20 is

    signal r_in_phase:  unsigned(19 downto 0);
    signal s_out_sin:   signed(17 downto 0);
    signal s_out_cos:   signed(17 downto 0);

begin

    -- Instantiate core.
    gen0: entity work.sincos_gen_d18_p20
        port map (
            clk             => clk,
            clk_en          => clk_en,
            in_phase        => r_in_phase,
            out_sin         => s_out_sin,
            out_cos         => s_out_cos );

    -- Input/output flip-flops.
    process (clk) is
    begin
        if rising_edge(clk) then
            r_in_phase  <= unsigned(in_phase);
            out_sin     <= std_logic_vector(s_out_sin);
            out_cos     <= std_logic_vector(s_out_cos);
        end if;
    end process;

end architecture;
