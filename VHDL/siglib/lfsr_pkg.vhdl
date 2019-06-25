-------------------------------------------------------------------------------
--! @file       lfsr_pkg.vhdl
--! @author     Fixitfetish
--! @date       12/May/2019
--! @version    0.30
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Binary operations
--!
package lfsr_pkg is

  type integer_vector_array is array(integer range <>) of integer_vector;

  -- http://courses.cse.tamu.edu/walker/csce680/lfsr_table.pdf
  constant MAXIMUM_LENGTH_POLY_4 : integer_vector_array(18 to 99)(0 to 3) := (
    (18,17,16,13),
    (19,18,17,14),
    (20,19,16,14),
    (21,20,19,16),
    (22,19,18,17),
    (23,22,20,18),
    (24,23,21,20),
    (25,24,23,22),
    (26,25,24,20),
    (27,26,25,22),
    (28,27,24,22),
    (29,28,27,25),
    (30,29,26,24),
    (31,30,29,28),
    (32,30,26,25),
    (33,32,29,27),
    (34,31,30,26),
    (35,34,28,27),
    (36,35,29,28),
    (37,36,33,31),
    (38,37,33,32),
    (39,38,35,32),
    (40,37,36,35),
    (41,40,39,38),
    (42,40,37,35),
    (43,42,38,37),
    (44,42,39,38),
    (45,44,42,41),
    (46,40,39,38),
    (47,46,43,42),
    (48,44,41,39),
    (49,45,44,43),
    (50,48,47,46),
    (51,50,48,45),
    (52,51,49,46),
    (53,52,51,47),
    (54,51,48,46),
    (55,54,53,49),
    (56,54,52,49),
    (57,55,54,52),
    (58,57,53,52),
    (59,57,55,52),
    (60,58,56,55),
    (61,60,59,56),
    (62,59,57,56),
    (63,62,59,58),
    (64,63,61,60),
    (65,64,62,61),
    (66,60,58,57),
    (67,66,65,62),
    (68,67,63,61),
    (69,67,64,63),
    (70,69,67,65),
    (71,70,68,66),
    (72,69,63,62),
    (73,71,70,69),
    (74,71,70,67),
    (75,74,72,69),
    (76,74,72,71),
    (77,75,72,71),
    (78,77,76,71),
    (79,77,76,75),
    (80,78,76,71),
    (81,79,78,75),
    (82,78,76,73),
    (83,81,79,76),
    (84,83,77,75),
    (85,84,83,77),
    (86,84,81,80),
    (87,86,82,80),
    (88,80,79,77),
    (89,86,84,83),
    (90,88,87,85),
    (91,90,86,83),
    (92,90,87,86),
    (93,91,90,87),
    (94,93,89,88),
    (95,94,90,88),
    (96,90,87,86),
    (97,95,93,91),
    (98,97,91,90),
    (99,95,94,92)
  );

  type std_logic_vector_array is array(integer range <>) of std_logic_vector;

  -- binary matrix, 2-dimensional
  type std_logic_matrix2 is array(integer range <>,integer range <>) of std_logic;

  -- binary identity matrix
  function eye(
    L : positive
  ) return std_logic_vector_array;

  -- transpose binary SLV array
  function transpose(
    m : std_logic_vector_array -- matrix of size R x C
  ) return std_logic_vector_array;
  
  -- binary scalar product
  function mult(
    v1 : std_logic_vector; -- (row) vector of length L
    v2 : std_logic_vector  -- (column) vector of length L
  ) return std_logic;

  -- binary multiplication of row vector with matrix
  function mult(
    v : std_logic_vector;      -- row vector of length L
    m : std_logic_vector_array -- matrix of size L x C
  ) return std_logic_vector;

  -- binary multiplication of matrix with column vector
  function mult(
    m : std_logic_vector_array; -- matrix of size R x L
    v : std_logic_vector        -- column vector of length L
  ) return std_logic_vector;

  -- binary multiplication of two matrices
  function mult(
    ml : std_logic_vector_array; -- left matrix of size R x N 
    mr : std_logic_vector_array  -- right matrix of size N x C
  ) return std_logic_vector_array;

  -- left/right concatenation of two matrices with same number of rows
  function cat_lr(
    ml : std_logic_vector_array; -- left
    mr : std_logic_vector_array  -- right
  ) return std_logic_vector_array;

  -- power of binary square matrix
  function pow(
     base : std_logic_vector_array; -- square matrix 
     exp : natural                  -- exponent
  ) return std_logic_vector_array;

  -- inverse of binary square matrix
  function inv(
     m : std_logic_vector_array -- square matrix
  ) return std_logic_vector_array;

end package;

-------------------------------------------------------------------------------

package body lfsr_pkg is

  -- binary identity matrix
  function eye(
    L : positive
  ) return std_logic_vector_array is
    variable res : std_logic_vector_array(L-1 downto 0)(L-1 downto 0);
  begin
    res := (others=>(others=>'0'));
    for j in res'range loop res(j)(j):='1'; end loop;
    return res;
  end function;

  -- transpose binary SLV array
  function transpose(
    m : std_logic_vector_array -- matrix of size R x C
  ) return std_logic_vector_array is
    constant ROWS : positive := m'length;
    constant COLS : positive := m(m'left)'length;
    alias mm : std_logic_vector_array(ROWS-1 downto 0)(COLS-1 downto 0) is m; -- default range
    variable res : std_logic_vector_array(COLS-1 downto 0)(ROWS-1 downto 0);
  begin
    for r in ROWS-1 downto 0 loop
      for c in COLS-1 downto 0 loop
        res(c)(r) := mm(r)(c);
      end loop;
    end loop;
    return res;
  end function;

  -- binary scalar product
  function mult(
    v1 : std_logic_vector; -- (row) vector of length L
    v2 : std_logic_vector  -- (column) vector of length L
  ) return std_logic is
    alias xv2 : std_logic_vector(v1'range) is v2;
    variable temp : std_logic_vector(v1'range);
    variable res : std_logic;
  begin
    res := '0';
    temp := v1 and xv2;
    for n in temp'range loop res:=res xor temp(n); end loop;
    return res;
  end function;

  -- binary multiplication of row vector with matrix
  function mult(
    v : std_logic_vector;      -- row vector of length L
    m : std_logic_vector_array -- matrix of size L x C
  ) return std_logic_vector is
    constant L : positive := v'length;
    constant C : positive := m(m'left)'length;
    variable mt : std_logic_vector_array(C-1 downto 0)(L-1 downto 0);
    variable res : std_logic_vector(C-1 downto 0);
  begin
    mt := transpose(m);
    for i in C-1 downto 0 loop 
      res(i) := mult(v,mt(i)); -- scalar product 
    end loop;
    return res;
  end function;

  -- binary multiplication of matrix with column vector
  function mult(
    m : std_logic_vector_array; -- matrix of size R x L
    v : std_logic_vector        -- column vector of length L
  ) return std_logic_vector is
    constant L : positive := v'length;
    constant R : positive := m'length;
    alias mm : std_logic_vector_array(R-1 downto 0)(L-1 downto 0) is m; -- default range
    variable res : std_logic_vector(R-1 downto 0);
  begin
    for i in res'range loop 
      res(i) := mult(mm(i),v); -- scalar product 
    end loop;
    return res;
  end function;

  -- binary multiplication of two matrices
  function mult(
    ml : std_logic_vector_array; -- left matrix of size R x N 
    mr : std_logic_vector_array  -- right matrix of size N x C
  ) return std_logic_vector_array is
    constant C : positive := mr(mr'left)'length;
    variable res : std_logic_vector_array(ml'range)(C-1 downto 0);
  begin
    for i in ml'range loop
      res(i) := mult(ml(i), mr);
    end loop;
    return res; -- result is a R x C matrix 
  end function;

  -- left/right concatenation of two matrices with same number of rows
  function cat_lr(
    ml : std_logic_vector_array; -- left
    mr : std_logic_vector_array  -- right
  ) return std_logic_vector_array is
    constant RL : positive := ml'length;
    constant CL : positive := ml(ml'left)'length;
    constant RR : positive := mr'length;
    constant CR : positive := mr(mr'left)'length;
    alias xml : std_logic_vector_array(RL downto 1)(CL downto 1) is ml; -- default range
    alias xmr : std_logic_vector_array(RR downto 1)(CR downto 1) is mr; -- default range
    variable res : std_logic_vector_array(RL downto 1)(CL+CR downto 1);
  begin
    assert (RL=RR)
      report "ERROR : For left/right concatenation of two matrices both must have the same number of rows."
      severity failure;
    for r in res'range loop
      res(r)(CR downto 1) := xmr(r);
      res(r)(CL+CR downto CR+1) := xml(r);
    end loop;
    return res; 
  end function;

  -- power of binary square matrix
  function pow(
     base : std_logic_vector_array; -- square matrix 
     exp : natural -- exponent
   ) return std_logic_vector_array is
    constant L : positive := base'length;
    variable uexp : unsigned(30 downto 0);
    variable fac : std_logic_vector_array(L-1 downto 0)(L-1 downto 0);
    variable res : std_logic_vector_array(L-1 downto 0)(L-1 downto 0);
  begin
    uexp := to_unsigned(exp,uexp'length);
    res := eye(L); -- identity matrix
    fac := base;
    for n in 0 to uexp'length-1 loop
      if uexp(n)='1' then res:=mult(res,fac); end if;
      fac := mult(fac,fac);
    end loop;
    return res;
  end function;

  -- inverse of binary square matrix
  function inv(
     m : std_logic_vector_array -- square matrix
  ) return std_logic_vector_array is
    constant W : positive := m'length;
    variable temp : std_logic_vector_array(1 to W)(1 to 2*W);
    variable res : std_logic_vector_array(1 to W)(1 to W);
  begin
    -- Gauss-Jordan elimination algorithm
    temp := cat_lr(m,eye(W));
    -- convert left halve to upper/right triangular matrix
    for c in 1 to W-1 loop
      for r in c+1 to W loop
        if temp(r)(c)='1' then temp(r):=temp(r) xor temp(c); end if; 
      end loop;
    end loop;
    -- convert left halve to lower/left triangular matrix
    for c in W downto 2 loop
      for r in c-1 downto 1 loop
        if temp(r)(c)='1' then temp(r):=temp(r) xor temp(c); end if; 
      end loop;
    end loop;
    -- final result is the right halve
    for r in 1 to W loop
      res(r) := temp(r)(W+1 to 2*W);
    end loop;
    return res;
  end function;

end package body;
