library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

-- ROM emulation

entity dftmtx8 is
generic(
  IQ_WIDTH : positive range 8 to 32 := 16;  -- Real/Imag width in bits
  POWER_LD : positive range 7 to 31 := 15
);
port (
  clk  : in  std_logic;
  rst  : in  std_logic;
  idx  : in  unsigned(2 downto 0);
  conj : in  std_logic; -- complex conjugated
  dout : out std_logic_vector(8*2*IQ_WIDTH-1 downto 0)
);
begin
  assert (POWER_LD<=(IQ_WIDTH-1))
  report "ERROR in dftmtx8 : POWER_LD must be equal or smaller than IQ_WIDTH-1 ."
  severity failure;
end entity;

-------------------------------------------------------------------------------

architecture RTL of dftmtx8 is

  constant RSHIFT : positive := 31 - POWER_LD;

  type integer_vector is array(integer range <>) of integer;
  type integer_matrix8 is array(integer range <>) of integer_vector(0 to 7);

  -- 1 = 2^31 / sqrt(8) = 2147483648 / sqrt(8) = 759250125
  -- 1/sqrt(2)/ sqrt(8) = 1518500250 / sqrt(8) = 536870912
  constant LUT : integer_vector(-2 to 2) := (-759250125, -536870912, 0, 536870912, 759250125);


  -- 1 = 2^30 / sqrt(8) = 1073741824 / sqrt(8) = 379625062
  -- 1/sqrt(2)/ sqrt(8) =  759250125 / sqrt(8) = 268435456
--  constant LUT : integer_vector(-2 to 2) := (-379625062, -268435456, 0, 268435456, 379625062);
--  constant LUT : integer_vector(-2 to 2) := (-1073741824, -759250125, 0, 759250125, 1073741824);

  constant MAT_RE : integer_matrix8(0 to 7) :=
    ((  2,  2,  2,  2,  2,  2,  2,  2 ),
     (  2,  1,  0, -1, -2, -1,  0,  1 ), 
     (  2,  0, -2,  0,  2,  0, -2,  0 ), 
     (  2, -1,  0,  1, -2,  1,  0, -1 ),
     (  2, -2,  2, -2,  2, -2,  2, -2 ), 
     (  2, -1,  0,  1, -2,  1,  0, -1 ),
     (  2,  0, -2,  0,  2,  0, -2,  0 ), 
     (  2,  1,  0, -1, -2, -1,  0,  1 ) 
    );

  constant MAT_IM : integer_matrix8(0 to 7) :=
    ((  0,  0,  0,  0,  0,  0,  0,  0 ),
     (  0, -1, -2, -1,  0,  1,  2,  1 ),
     (  0, -2,  0,  2,  0, -2,  0,  2 ),
     (  0, -1,  2, -1,  0,  1, -2,  1 ),
     (  0,  0,  0,  0,  0,  0,  0,  0 ),
     (  0,  1, -2,  1,  0, -1,  2, -1 ),
     (  0,  2,  0, -2,  0,  2,  0, -2 ),
     (  0,  1,  2,  1,  0, -1, -2, -1 )
    );

begin

  p_rom : process(clk)
    variable v_idx : integer range 0 to 7;
    variable v_re, v_im : signed(31 downto 0);
    variable v_re_shifted, v_im_shifted : signed(IQ_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
     if rst='1' then
      dout <= (others=>'0');
     else
      v_idx := to_integer(idx);
      for n in 0 to 7 loop
        -- look-up
        v_re := to_signed(LUT(MAT_RE(v_idx)(n)), v_re'length);
        if conj='1' then
          -- complex conjugated
          v_im := - to_signed(LUT(MAT_IM(v_idx)(n)), v_im'length);
        else
          v_im := to_signed(LUT(MAT_IM(v_idx)(n)), v_im'length);
        end if;
        -- adjust bit width and scale
        v_re_shifted := RESIZE( SHIFT_RIGHT_ROUND(v_re, RSHIFT, nearest) , IQ_WIDTH);
        v_im_shifted := RESIZE( SHIFT_RIGHT_ROUND(v_im, RSHIFT, nearest) , IQ_WIDTH);
        -- map to SLV output
        dout((2*n+1)*IQ_WIDTH-1 downto (2*n+0)*IQ_WIDTH) <= std_logic_vector(v_re_shifted);
        dout((2*n+2)*IQ_WIDTH-1 downto (2*n+1)*IQ_WIDTH) <= std_logic_vector(v_im_shifted);
      end loop;
     end if; --reset
    end if; --clock
  end process;

end architecture;
