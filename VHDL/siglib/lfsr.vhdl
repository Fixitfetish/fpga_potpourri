-------------------------------------------------------------------------------
--! @file       lfsr.vhdl
--! @author     Fixitfetish
--! @date       01/May/2019
--! @version    0.65
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library siglib;
  use siglib.lfsr_pkg.all;

--! @brief Binary Galois/Fibonacci Linear Feedback Shift Register (LFSR).
--! Generation of pseudo random bit sequences.
--!
--! This implementation is based on vector/matrix multiplications.
--! The highest numbered exponent M defines the vector length N of the default
--! shift register (SR) and the seed. However, the implemented right shift
--! register length can be larger when the number of required output data bits
--! D is larger than M. In this case the SR is extended by X=D-M bits to the
--! length N=M+X.
--! Furthermore, the number of bit shifts per cycle S can be defined independent
--! of the SR length. S and N determine the shift logic.
--!
--! **Offset logic** is required when the number of initial offset bit shifts I is
--! greater than 0 , or when D>M (because X initial shifts are needed to fill the extension bits). 
--! The offset logic can be applied to either the input (before SR) or the output (after SR).
--! For efficiency reasons always apply the offset logic to the input when a constant seed is used.
--! Since the required constant offset and shift matrices are derived from generic
--! parameters, the calculation of matrices does not require any logic resources.
--! Just the shift and offset logic related multiplications require logic resources which
--! are usually optimized to a minimum by the synthesis tools.
--! 
--! **Galois versus Fibonacci** : 
--! Typically the Galois implementation is more efficient than the Fibonacci implementation
--! because only a single XOR operation is needed between two shift register bits,
--! hence higher frequencies can be achieved.
--! Nevertheless, if multiple bits of the Galois SR are output in one cycle then
--! only the bits right of the smallest tap (lowest numbered exponent) are valid
--! while the bits left of the smallest tap are still variable.
--! This limitation does not apply to the Fibonacci implementation since the 
--! SR bits are just shifted without modification.
--! Note that if just a pseudo random values are required but not the exact bit
--! sequence also the Galois implementation allows the full M or more bits in a
--! single cycle.
--!
--! @image html lfsr.svg "" width=800px
--!
--! @image html lfsr_wave.svg "" width=1200px
--!
--! **Examples** with parameters TAPS=(16,14,13,11) , FIBONACCI , SHIFTS_PER_CYCLE=8 , OFFSET=0, default seed
--!
--! Example 1 : Request and Acknowledge Mode, disabled output register
--! @image html lfsr_wave_without_output_reg.jpg "" width=1500px
--!
--! Example 2 : Request and Acknowledge Mode, enabled output register
--! @image html lfsr_wave_with_output_reg.jpg "" width=1500px
--!
--! Example of maximal-length polynomials :
--!
--! Length | Exponents/Taps      | Length | Exponents/Taps   
--! :-----:|:-------------------:|:------:|:---------------: 
--!   1    |  NA                 |   21   |  21, 19            
--!   2    |  2, 1               |   22   |  22, 21            
--!   3    |  3, 2               |   23   |  23, 18            
--!   4    |  4, 3               |   24   |  24, 23, 21, 20    
--!   5    |  5, 3               |   25   |  25, 22            
--!   6    |  6, 5               |   26   |  26, 25, 24, 20    
--!   7    |  7, 6               |   27   |  27, 26, 25, 22    
--!   8    |  8, 6, 5, 4         |   28   |  28, 25            
--!   9    |  9, 5               |   29   |  29, 27            
--!   10   |  10, 7              |   30   |  30, 29, 26, 24    
--!   11   |  11, 9              |   31   |  31, 28            
--!   12   |  12, 11, 8, 6       |   32   |  32, 30, 26, 25    
--!   13   |  13, 12, 10, 6      |   33   |  33, 20            
--!   14   |  14, 13, 11, 9      |   34   |  34, 31, 30, 26    
--!   15   |  15, 14             |   35   |  35, 33            
--!   16   |  16, 14, 13, 11     |   36   |  36, 25            
--!   17   |  17, 14             |   37   |  37, 36, 33, 31    
--!   18   |  18, 11             |   38   |  38, 37, 33, 32    
--!   19   |  19, 18, 17, 14     |   39   |  39, 35            
--!   20   |  20, 17             |   40   |  40, 38, 21, 19    
--!
entity lfsr is
generic (
  --! @brief Feedback polynomial exponents (taps). List of positive integers in descending order.
  --! The first leftmost (greatest) exponent defines the standard length M of the shift register.
  --! Example for a 12-bit shift register with polynomial x^12 + x^11 + x^8 + x^6 + 1 : TAPS=>(12,11,8,6)
  TAPS : integer_vector;
  --! @brief Enable FIBONACCI implementation. Default is the GALOIS implementation.
  FIBONACCI : boolean := false;
  --! @brief Number of bit shifts per cycle.
  SHIFTS_PER_CYCLE : positive := 1;
  --! @brief In the default request mode a valid value is output with a fixed delay after the request.
  --! In acknowledge mode (first word fall through) the output always shows the next value 
  --! which must be acknowledged to get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := false;
  --! @brief Offset (fast-forward) in number of bit shifts I (default is I=0).
  --! If I>0 then additional I shifts are implemented, either as input offset
  --! logic (seed fast-forward) or as output offset logic (SR fast-forward).
  --! The offset logic can significantly increase the complexity and therefore cause timing issues.
  --! Furthermore, an additional offset X is automatically implemented to fill the X extensions bits,
  --! i.e. when the number of output bits D is greater than M.
  OFFSET : natural := 0;
  --! @brief By default the offset is applied at the input, i.e. the seed is transformed before it
  --! is loaded into the shift register. This is preferred especially when the seed is constant since
  --! only the constant is transformed and additional logic is not implemented.
  --! If the offset is applied to the output then the offset logic is moved behind the shift register.
  --! Moving the offset logic to the output can be beneficial for timing,
  --! e.g. when the output is followed by pipeline registers anyway.
  OFFSET_AT_OUTPUT : boolean := false;
  --! @brief Number required output bits D.
  --! The default D=0 means that output width is equal to the standard shift register width M (see TAPS).
  --! For 0 < D < M the number of output bits is limited to D.
  --! For D >= M the full (extended) shift register contents is provided at the output. 
  OUTPUT_WIDTH : natural := 0;
  --! @brief Enable additional output register. When enabled the load to output delay and
  --! request to output delay is 2 cycles.
  OUTPUT_REG : boolean := false
);
port (
  --! Clock
  clk          : in  std_logic;
  --! Initialize/load shift register with seed
  load         : in  std_logic;
  --! Request or Acknowledge according to selected mode
  req_ack      : in  std_logic := '1';
  --! Initial shift register contents after reset. By default only the rightmost bit is set.
  seed         : in  std_logic_vector(TAPS(TAPS'left)-1 downto 0) := (0=>'1', others=>'0');
  --! @brief Shift register output, right aligned. Is shifted right by SHIFTS_PER_CYCLE bits in each cycle.
  --! Width depends on the generic OUTPUT_WIDTH.
  dout         : out std_logic_vector;
  --! Shift register output valid (request mode) or ready (acknowledge mode)
  dout_vld_rdy : out std_logic;
  --! First output value after loading
  dout_first   : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of lfsr is
  
  function MAX(l,r:integer) return integer is
  begin
    if l>r then return l; else return r; end if;
  end function;

  -- standard shift register length
  constant M : positive := TAPS(TAPS'left);

  -- implemented (extended) shift register width
  constant N : positive := MAX(M,OUTPUT_WIDTH);
  
  -- Final number of output bits
  function D return positive is begin
    if OUTPUT_WIDTH=0 then return M; else return OUTPUT_WIDTH; end if;
  end function;

  -- shift register extension bits
  constant X : natural := N - M;
  
  -- number of initial offset bit shifts
  constant I : natural := OFFSET + X;

  -- determine companion matrix according to selected implementation type
  function get_companion_matrix(
    constant W : positive; -- shift register width
    constant taplist : integer_vector;
    fibo : boolean := false -- false=Galois, true=Fibonacci
  ) return std_logic_vector_array is
    constant L : positive := taplist(taplist'left); -- leftmost tap defines the polynomial length
    constant XX : natural := W-L;
    variable res : std_logic_vector_array(W downto 1)(W downto 1);
  begin
    res := (others=>(others=>'0'));
    -- first W-1 rows have right-aligned identity matrix
    for j in W downto 2 loop res(j)(j-1):='1'; end loop;
    if fibo then
      -- Fibonacci : mirrored polynomial top-aligned into first column
      for t in taplist'range loop res(W-taplist(t)+1)(W):='1'; end loop;
    else
      -- Galois : polynomial left-aligned in last row
      for t in taplist'range loop res(1)(XX+taplist(t)):='1'; end loop;
    end if;
    return res;
  end function;

  -- Transform matrix (Galois <=> Fibonacci)
  -- Transforms shift register values between Galois and Fibonacci representation
  -- to compensate the sequence offset between both.
  -- Considered are also shift registers which are extended by X bits to the right.
  -- The R bits right of the smallest tap are the same for Galois and Fibonacci,
  -- i.e. only the L bits left of the smallest tap must be transformed.
  function get_transform_matrix(
    constant W : positive; -- shift register width
    constant taplist : integer_vector
  ) return std_logic_vector_array is
    constant R : positive := taplist(taplist'right); -- leftmost tap defines the polynomial length
    constant L : natural := taplist(taplist'left) - R;
    variable cm : std_logic_vector_array(W downto 1)(W downto 1);
    variable tm : std_logic_vector_array(W downto 1)(W downto 1);
    variable res : std_logic_vector_array(W downto 1)(W downto 1);
  begin
    cm := get_companion_matrix(W=>W, taplist=>taplist, fibo=>false);
    tm := pow(cm,L);
    res := eye(W);
    -- replace first L columns
    for col in W downto W-L+1 loop
      for row in W downto 1 loop
        res(row)(col) := tm(row)(col-L);
      end loop;
    end loop;
    return res;
  end function;

  -- companion matrix
  constant CMAT : std_logic_vector_array := get_companion_matrix(W=>N, taplist=>TAPS, fibo=>FIBONACCI);

  -- transform matrix (Galois <=> Fibonacci)
  constant TMAT : std_logic_vector_array := get_transform_matrix(W=>N, taplist=>TAPS);

  -- offset matrix (fast-forward)
  constant OMAT : std_logic_vector_array := pow(CMAT,I);

  -- shift matrix
  constant SMAT : std_logic_vector_array := pow(CMAT,SHIFTS_PER_CYCLE);

  -- shift register
  signal sr, sr_i : std_logic_vector(N downto 1);
  
  -- first shift register value after loading
  signal sr_first : std_logic := '0';

  -- seed after offset/transform logic
  signal seed_i : std_logic_vector(N downto 1);

  signal shift : std_logic := '0';
  
begin

  -- Input offset/transform logic 
  -- (does not require any logic resources when seed input is constant)
  p_in_logic : process(seed)
    variable v_seed : std_logic_vector(N-1 downto 0);
  begin
    -- seed left-aligned, bit extension right-aligned
    v_seed := (others=>'-');
    v_seed(N-1 downto X) := seed;
    if OFFSET_AT_OUTPUT then
      seed_i <= v_seed; -- without offset logic
    else
      seed_i <= mult(v_seed,OMAT); -- including offset logic
    end if;
  end process;


  -- shift register logic
  p_sr : process(clk)
  begin
    if rising_edge(clk) then
      if load='1' then
        -- shift register initialization
        sr <= seed_i;
        sr_first <= '1';
      elsif shift='1' then
        -- shift logic
        sr <= mult(sr,SMAT);
        sr_first <= '0';
      end if;
    end if;
  end process;


  -- Output offset/transform logic 
  p_out_logic : process(sr)
  begin
    if OFFSET_AT_OUTPUT then
      sr_i <= mult(sr,OMAT);
    else
      sr_i <= sr;
    end if;
  end process;


  -- Request Mode
  g_req : if not ACKNOWLEDGE_MODE generate
    signal sr_vld : std_logic := '0';
    signal dout_vld_i : std_logic;
  begin
    p : process(clk)
    begin
      if rising_edge(clk) then
        if req_ack='1' then
          sr_vld <= '1';
        elsif load='1' then
          sr_vld <= '0';
        end if;
        dout_vld_i <= req_ack;
      end if;
    end process;
    shift <= req_ack and sr_vld;
    
    g_oreg_off : if not OUTPUT_REG generate
      dout <= sr_i(D downto 1);
      dout_vld_rdy <= dout_vld_i;
      dout_first <= sr_first;
    end generate;

    g_oreg_on : if OUTPUT_REG generate
      dout <= sr_i(D downto 1) when rising_edge(clk);
      dout_vld_rdy <= dout_vld_i when rising_edge(clk);
      dout_first <= sr_first when rising_edge(clk);
    end generate;
    
  end generate; -- Request Mode


  -- Acknowledge Mode
  g_ack : if ACKNOWLEDGE_MODE generate

    g_oreg_off : if not OUTPUT_REG generate
      dout_vld_rdy <= not load;
      dout_first <= sr_first;
      dout <= sr_i(D downto 1);
      shift <= req_ack and not load;
    end generate;

    g_oreg_on : if OUTPUT_REG generate
      signal rdy : std_logic;
    begin
      rdy <= not load when rising_edge(clk);
      shift <= sr_first or (rdy and req_ack);
      p : process(clk)
      begin
        if rising_edge(clk) then
          if load='1' then
            dout_first <= '0';
            dout <= (D downto 1=>'-');
          elsif sr_first='1' or shift='1' then 
            dout_first <= sr_first;
            dout <= sr_i(D downto 1);
          end if;
        end if;
      end process;
      dout_vld_rdy <= rdy;
    end generate;
    
  end generate; -- Acknowledge Mode


end architecture;
