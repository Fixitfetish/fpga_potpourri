-------------------------------------------------------------------------------
--! @file       delay_dsp.behave.vhdl
--! @author     Fixitfetish
--! @date       07/May/2017
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;

architecture behave of delay_dsp is
  
  type t_pipe is array(integer range <>) of std_logic_vector(din'range);
  signal pipe : t_pipe(1 to NUM_PIPELINE_STAGES);  

begin

  g_flush_off : if FLUSH_RESET_VALUE'length/=din'length generate

    p_pipe : process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          pipe <= (others=>(others=>'0'));
        elsif clkena='1' then
          pipe(2 to pipe'length) <= pipe(1 to pipe'length-1);
          pipe(1) <= din;
        end if;
      end if;
     end process;

  end generate;


  g_flush_on : if FLUSH_RESET_VALUE'length=din'length generate

   -- pipeline is active with reset or clock enable
   g_flush_ena_off : if not FLUSH_WITH_CLKENA generate
    p_pipe : process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' or clkena='1' then
          pipe(2 to pipe'length) <= pipe(1 to pipe'length-1);
        end if;
        if rst='1' then
          pipe(1) <= FLUSH_RESET_VALUE;
        elsif clkena='1' then
          pipe(1) <= din;
        end if;
      end if;
    end process;
   end generate;

   -- pipeline is active with clock enable only
   g_flush_ena_on : if FLUSH_WITH_CLKENA generate
    p_pipe : process(clk)
    begin
      if rising_edge(clk) then
        if clkena='1' then
          pipe(2 to pipe'length) <= pipe(1 to pipe'length-1);
          if rst='1' then
            pipe(1) <= FLUSH_RESET_VALUE;
          else
            pipe(1) <= din;
          end if;
        end if;
      end if;
    end process;
   end generate;

  end generate;
  
  -- final output
  dout <= pipe(pipe'length);

end architecture;
