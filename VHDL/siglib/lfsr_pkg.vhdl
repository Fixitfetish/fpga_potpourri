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
