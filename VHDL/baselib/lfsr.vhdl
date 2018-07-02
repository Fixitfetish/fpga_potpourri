-------------------------------------------------------------------------------
--! @file       lfsr.vhdl
--! @author     Fixitfetish
--! @date       02/Jul/2018
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;

--! @brief Binary Galois Linear Feedback Shift Register (LFSR)
--!
--! Example of maximal-length polynomials :
--!
--! Length | Exponents
--! :-----:|:--------:
--!   2    |  2, 1         
--!   3    |  3, 2         
--!   4    |  4, 3         
--!   5    |  5, 3         
--!   6    |  6, 5         
--!   7    |  7, 6         
--!   8    |  8, 6, 5, 4   
--!   9    |  9, 5         
--!   10   |  10, 7        
--!   11   |  11, 9        
--!   12   |  12, 11, 8, 6 
--!   14   |  14, 13, 11, 9      
--!   15   |  15, 14             
--!   16   |  16, 14, 13, 11     
--!   17   |  17, 14             
--!   18   |  18, 11             
--!   19   |  19, 18, 17, 14     
--!   20   |  20, 17             
--!   21   |  21, 19             
--!   22   |  22, 21             
--!   23   |  23, 18             
--!   24   |  24, 23, 21, 20
--!
    
entity lfsr is
generic (
  --! @brief Feedback polynomial exponents.
  --! List of positive integers in descending order.
  --! The first left-most (greatest) exponent defines the length of the shift register.
  --! Example for a 12-bit shift register: EXPONENTS=>(12,11,8,6)
  EXPONENTS : integer_vector
);
port (
  --! Clock
  clk       : in  std_logic;
  --! Synchronous reset
  rst       : in  std_logic;
  --! Initial shift register contents after reset
  load_init : in  std_logic_vector(EXPONENTS(EXPONENTS'left) downto 1);
  --! clock enable
  clk_ena   : in  std_logic := '1';
  --! Data/bit output
  data_out  : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of lfsr is
  
  signal LENGTH : integer := EXPONENTS(EXPONENTS'left);
  signal sr : std_logic_vector(LENGTH downto 1);
  
begin
    
  p : process(clk)
    variable v_exp_idx : integer;
  begin
    if rising_edge(clk) then
      if rst='1' then
        -- shift register initialization
        sr <= load_init;
        
      elsif clk_ena='1' then
        sr(LENGTH) <= sr(1);
        v_exp_idx := 1;
        -- ignore first exponent since it must be always equal to LENGTH
        for n in LENGTH-1 downto 1 loop
          sr(n) <= sr(n+1); -- default without XOR
          if v_exp_idx<EXPONENTS'length then
            -- there are still exponents in list which have not been considered yet
            if n=EXPONENTS(EXPONENTS'left + v_exp_idx) then
              sr(n) <= sr(n+1) xor sr(1);
              v_exp_idx := v_exp_idx + 1;
            end if;
          end if;
        end loop;
     
      end if;
    end if; 
  end process;

  -- final output
  data_out <= sr(1);

end architecture;
