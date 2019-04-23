-------------------------------------------------------------------------------
--! @file       lfsr.vhdl
--! @author     Fixitfetish
--! @date       22/Apr/2019
--! @version    0.30
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
library baselib;
  use baselib.std_logic_extension.all;

--! @brief Binary Galois/Fibonacci Linear Feedback Shift Register (LFSR).
--! Generation of pseudo random bit sequences.
--!
--! This implementation is based on vector/matrix multiplications.
--! A right shift register (SR) of length M is multiplied with a matrix.
--! The length M is given by the highest numbered exponent.
--! The required constant matrices are derived from generic parameters,
--! hence the calculation of matrices does not require any logic resources.
--! Just shift logic related multiplications require logic resources which
--! are usually optimized to a minimum by the synthesis tools.
--! 
--! **Galois versus Fibonacci** : 
--! Typically the Galois implementation is more efficient than the Fibonacci implementation
--! because only a single XOR operation is needed between two shift register bits,
--! hence higher frequencies can be achieved.
--! Nevertheless, if multiple bits are shifted in one cycle then the Galois implementation
--! only works correctly when the number of shifts does not exceed the lowest numbered exponent.
--! This limitation does not apply to the Fibonacci implementation since the number of shifts
--! per cycle is just limited by the number of shift register bits.
--! Note that if just a pseudo random values are required but not the exact bit sequence also
--! the Galois implementation allows shifting the full M bits in a single cycle. 
--!
--! Example of maximal-length polynomials :
--!
--! Length | Exponents/Taps
--! :-----:|:---------------:
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
--!   13   |  13, 12, 10, 6
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
--!   25   |  25, 22
--!   26   |  26, 25, 24, 20 
--!   27   |  27, 26, 25, 22 
--!   28   |  28, 25
--!   29   |  29, 27
--!   30   |  30, 29, 26, 24
--!   31   |  31, 28
--!   32   |  32, 30, 26, 25
--!   33   |  33, 20
--!   34   |  34, 31, 30, 26
--!   35   |  35, 33
--!   36   |  36, 25
--!   37   |  37, 36, 33, 31
--!   38   |  38, 37, 33, 32
--!   39   |  39, 35
--!   40   |  40, 38, 21, 19
--!
entity lfsr is
generic (
  --! @brief Feedback polynomial exponents (taps). List of positive integers in descending order.
  --! The first leftmost (greatest) exponent defines the length of the shift register.
  --! Example for a 12-bit shift register with polynomial x^12 + x^11 + x^8 + x^6 + 1 : EXPONENTS=>(12,11,8,6)
  EXPONENTS : integer_vector;
  --! @brief Enable FIBONACCI implementation. Default is the GALOIS implementation.
  FIBONACCI : boolean := false;
  --! @brief Number of shifts/bits per cycle. Cannot exceed the length of the shift register.
  BITS_PER_CYCLE : positive := 1;
  --! @brief Offset (fast-forward) in number of bit shifts (default is 0).
  --! If OFFSET>0 then the shift register is initialized with the corresponding offset seed.
  --! In case the seed input is not constant additional logic is required which can cause timing issues. 
  OFFSET : natural := 0;
  --! @brief By default the offset is applied at the input, i.e. the seed is transformed before it
  --! is loaded into the shift register. If the offset is applied to the output then the transform logic
  --! is moved behind the shift register. Moving the transform logic to the output can be beneficial
  --! for the timing e.g. when the output is followed by pipeline registers anyway.
  OFFSET_AT_OUTPUT : boolean := false
);
port (
  --! Synchronous reset, required to initialize shift register with seed
  rst       : in  std_logic;
  --! Clock
  clk       : in  std_logic;
  --! Clock enable
  clk_ena   : in  std_logic := '1';
  --! Initial shift register contents after reset. By default only the rightmost bit is set.
  seed      : in  std_logic_vector(EXPONENTS(EXPONENTS'left)-1 downto 0) := (0=>'1', others=>'0');
  --! Shift register output, right aligned. Is shifted right by BITS_PER_CYCLE bits in each cycle.
  dout      : out std_logic_vector(EXPONENTS(EXPONENTS'left)-1 downto 0)
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (BITS_PER_CYCLE<=EXPONENTS(EXPONENTS'left))
    report "ERROR in " & lfsr'INSTANCE_NAME & " Number of bits per cycle cannot exceed the length of the shift register."
    severity failure;
  assert (FIBONACCI or BITS_PER_CYCLE<=EXPONENTS(EXPONENTS'right))
    report "Warning in " & lfsr'INSTANCE_NAME & " Galois: too many bits per cycle. Exact bit sequence order not possible."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of lfsr is
  
  -- Width of shift register in bits
  constant M : integer := EXPONENTS(EXPONENTS'left);

  -- shift register
  signal sr : std_logic_vector(M downto 1);

  -- determine companion matrix according to selected implementation
  function get_companion_matrix(
    taps : integer_vector;
    fibo : boolean := false -- false=Galois, true=Fibonacci
  ) return std_logic_vector_array is
    constant L : positive := taps(taps'left); -- leftmost tap defines the polynomial length
    variable res : std_logic_vector_array(L downto 1)(L downto 1);
  begin
    res := (others=>(others=>'0'));
    -- first rows have right-aligned identity matrix
    for j in L downto 2 loop res(j)(j-1):='1'; end loop;
    if fibo then
      -- Fibonacci : first column is mirrored polynomial
      for t in taps'range loop res(L-taps(t)+1)(L):='1'; end loop;
    else
      -- Galois : last row is polynomial
      for t in taps'range loop res(1)(taps(t)):='1'; end loop;
    end if;
    return res;
  end function;

  -- companion matrix
  constant CMAT : std_logic_vector_array := get_companion_matrix(taps=>EXPONENTS, fibo=>FIBONACCI);

  -- offset (fast-forward) matrix
  constant OMAT : std_logic_vector_array := pow(CMAT,OFFSET);

  -- shift matrix
  constant SMAT : std_logic_vector_array := pow(CMAT,BITS_PER_CYCLE);

begin

  p : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        -- shift register initialization
        if OFFSET_AT_OUTPUT then
          sr <= seed; -- without offset
        else
          sr <= mult(seed,OMAT); -- including offset
        end if;
      elsif clk_ena='1' then
        sr <= mult(sr,SMAT);
      end if;
    end if; 
  end process;

  -- final output
  g_out : if not OFFSET_AT_OUTPUT generate
    dout <= sr;
  end generate;

  g_offset : if OFFSET_AT_OUTPUT generate
    dout <= mult(sr,OMAT);
  end generate;

end architecture;
