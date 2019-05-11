-------------------------------------------------------------------------------
--! @file       cplx_vectorization.rtl.vhdl
--! @author     Fixitfetish
--! @date       17/Feb/2018
--! @version    0.41
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief Parallelize a complex data stream of N consecutive cycles into a complex
--! vector of length N.
--!
architecture rtl of cplx_vectorization is
  
  constant N : natural := vec_out'length;
  constant W : natural := ser_in.re'length;
  
  signal data_in : cplx_vector(0 to N-2)(re(W-1 downto 0),im(W-1 downto 0));
  signal next_idx : natural range 0 to N-1 := 0;

begin

  -- NOTE:
  -- Consider that vec_out'range might not be "0 to N-1" but e.g. "3 to N+2"

  p : process(clk)
    variable v_din : cplx_vector(0 to N-1)(re(W-1 downto 0),im(W-1 downto 0));
  begin
    if rising_edge(clk) then
      if rst='1' then
        data_in <= cplx_vector_reset(W,N-1);
        vec_out <= cplx_vector_reset(W,N);
        next_idx <= 0;
      elsif ser_in.vld='1' and next_idx=(N-1) then
        -- Output vector when last vector element has been provided.
        vec_out(vec_out'left to vec_out'right-1) <= data_in;
        vec_out(vec_out'right) <= ser_in;
        next_idx <= 0; -- prepare for new vector
      else
        if ser_in.vld='1' and (start='1' or next_idx/=0) then
          -- note: work-around with variable that also works with N=2
          v_din(0 to N-2) := data_in;
          v_din(N-1) := ser_in;
          data_in <= v_din(1 to N-1);
          next_idx <= next_idx + 1;
        end if;
        -- set output vector invalid while assembling input data
        for i in vec_out'range loop
          vec_out(i).vld<='0';
          vec_out(i).ovf<='0';
        end loop;
      end if;
    end if;
  end process;

end architecture;
