-------------------------------------------------------------------------------
--! @file       ieee_extension_types_1993.vhdl
--! @author     Fixitfetish
--! @date       01/May/2017
--! @version    0.15
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief This package provides types that are based on IEEE standard types.
--!
--! NOTE: a more or less compatible package is available for VHDL-2008.
--! The VHDL-2008 version of this package is much more flexible since code duplication
--! is not required to such an extent as it is for VHDL-1993. For that reason this 
--! VHDL-1993 version only provides a subset of bit widths. But this package can be
--! easily extended to any needed bit width.

package ieee_extension_types is

  -- predefined vector types that are introduced with VHDL-2008
  type integer_vector is array(natural range <>) of integer;
  type boolean_vector is array(natural range <>) of boolean;
  type real_vector is array(natural range <>) of real;
  type time_vector is array(natural range <>) of time;

  type slv16_array  is array(integer range<>) of std_logic_vector(15 downto 0);
  type slv32_array  is array(integer range<>) of std_logic_vector(31 downto 0);

  -----------------------------------------------------------------------------
  -- UNSIGNED vector types
  type unsigned4_vector  is array(integer range<>) of unsigned( 3 downto 0);
  type unsigned5_vector  is array(integer range<>) of unsigned( 4 downto 0);
  type unsigned6_vector  is array(integer range<>) of unsigned( 5 downto 0);
  type unsigned7_vector  is array(integer range<>) of unsigned( 6 downto 0);
  type unsigned8_vector  is array(integer range<>) of unsigned( 7 downto 0);
  type unsigned9_vector  is array(integer range<>) of unsigned( 8 downto 0);
  type unsigned10_vector is array(integer range<>) of unsigned( 9 downto 0);
  type unsigned11_vector is array(integer range<>) of unsigned(10 downto 0);
  type unsigned12_vector is array(integer range<>) of unsigned(11 downto 0);
  type unsigned13_vector is array(integer range<>) of unsigned(12 downto 0);
  type unsigned14_vector is array(integer range<>) of unsigned(13 downto 0);
  type unsigned15_vector is array(integer range<>) of unsigned(14 downto 0);
  type unsigned16_vector is array(integer range<>) of unsigned(15 downto 0);
  type unsigned17_vector is array(integer range<>) of unsigned(16 downto 0);
  type unsigned18_vector is array(integer range<>) of unsigned(17 downto 0);
  type unsigned19_vector is array(integer range<>) of unsigned(18 downto 0);
  type unsigned20_vector is array(integer range<>) of unsigned(19 downto 0);
  type unsigned21_vector is array(integer range<>) of unsigned(20 downto 0);
  type unsigned22_vector is array(integer range<>) of unsigned(21 downto 0);
  type unsigned23_vector is array(integer range<>) of unsigned(22 downto 0);
  type unsigned24_vector is array(integer range<>) of unsigned(23 downto 0);
  type unsigned25_vector is array(integer range<>) of unsigned(24 downto 0);
  type unsigned26_vector is array(integer range<>) of unsigned(25 downto 0);
  type unsigned27_vector is array(integer range<>) of unsigned(26 downto 0);
  type unsigned28_vector is array(integer range<>) of unsigned(27 downto 0);
  type unsigned29_vector is array(integer range<>) of unsigned(28 downto 0);
  type unsigned30_vector is array(integer range<>) of unsigned(29 downto 0);
  type unsigned31_vector is array(integer range<>) of unsigned(30 downto 0);
  type unsigned32_vector is array(integer range<>) of unsigned(31 downto 0);
  type unsigned33_vector is array(integer range<>) of unsigned(32 downto 0);
  type unsigned34_vector is array(integer range<>) of unsigned(33 downto 0);
  type unsigned35_vector is array(integer range<>) of unsigned(34 downto 0);
  type unsigned36_vector is array(integer range<>) of unsigned(35 downto 0);
  type unsigned37_vector is array(integer range<>) of unsigned(36 downto 0);
  type unsigned38_vector is array(integer range<>) of unsigned(37 downto 0);
  type unsigned39_vector is array(integer range<>) of unsigned(38 downto 0);
  type unsigned40_vector is array(integer range<>) of unsigned(39 downto 0);
  type unsigned41_vector is array(integer range<>) of unsigned(40 downto 0);
  type unsigned42_vector is array(integer range<>) of unsigned(41 downto 0);
  type unsigned43_vector is array(integer range<>) of unsigned(42 downto 0);
  type unsigned44_vector is array(integer range<>) of unsigned(43 downto 0);
  type unsigned45_vector is array(integer range<>) of unsigned(44 downto 0);
  type unsigned46_vector is array(integer range<>) of unsigned(45 downto 0);
  type unsigned47_vector is array(integer range<>) of unsigned(46 downto 0);
  type unsigned48_vector is array(integer range<>) of unsigned(47 downto 0);

  --! default standard unsigned vector type
  alias unsigned_vector is unsigned18_vector;

  -----------------------------------------------------------------------------
  -- SIGNED vector types
  type signed4_vector  is array(integer range<>) of signed( 3 downto 0);
  type signed5_vector  is array(integer range<>) of signed( 4 downto 0);
  type signed6_vector  is array(integer range<>) of signed( 5 downto 0);
  type signed7_vector  is array(integer range<>) of signed( 6 downto 0);
  type signed8_vector  is array(integer range<>) of signed( 7 downto 0);
  type signed9_vector  is array(integer range<>) of signed( 8 downto 0);
  type signed10_vector is array(integer range<>) of signed( 9 downto 0);
  type signed11_vector is array(integer range<>) of signed(10 downto 0);
  type signed12_vector is array(integer range<>) of signed(11 downto 0);
  type signed13_vector is array(integer range<>) of signed(12 downto 0);
  type signed14_vector is array(integer range<>) of signed(13 downto 0);
  type signed15_vector is array(integer range<>) of signed(14 downto 0);
  type signed16_vector is array(integer range<>) of signed(15 downto 0);
  type signed17_vector is array(integer range<>) of signed(16 downto 0);
  type signed18_vector is array(integer range<>) of signed(17 downto 0);
  type signed19_vector is array(integer range<>) of signed(18 downto 0);
  type signed20_vector is array(integer range<>) of signed(19 downto 0);
  type signed21_vector is array(integer range<>) of signed(20 downto 0);
  type signed22_vector is array(integer range<>) of signed(21 downto 0);
  type signed23_vector is array(integer range<>) of signed(22 downto 0);
  type signed24_vector is array(integer range<>) of signed(23 downto 0);
  type signed25_vector is array(integer range<>) of signed(24 downto 0);
  type signed26_vector is array(integer range<>) of signed(25 downto 0);
  type signed27_vector is array(integer range<>) of signed(26 downto 0);
  type signed28_vector is array(integer range<>) of signed(27 downto 0);
  type signed29_vector is array(integer range<>) of signed(28 downto 0);
  type signed30_vector is array(integer range<>) of signed(29 downto 0);
  type signed31_vector is array(integer range<>) of signed(30 downto 0);
  type signed32_vector is array(integer range<>) of signed(31 downto 0);
  type signed33_vector is array(integer range<>) of signed(32 downto 0);
  type signed34_vector is array(integer range<>) of signed(33 downto 0);
  type signed35_vector is array(integer range<>) of signed(34 downto 0);
  type signed36_vector is array(integer range<>) of signed(35 downto 0);
  type signed37_vector is array(integer range<>) of signed(36 downto 0);
  type signed38_vector is array(integer range<>) of signed(37 downto 0);
  type signed39_vector is array(integer range<>) of signed(38 downto 0);
  type signed40_vector is array(integer range<>) of signed(39 downto 0);
  type signed41_vector is array(integer range<>) of signed(40 downto 0);
  type signed42_vector is array(integer range<>) of signed(41 downto 0);
  type signed43_vector is array(integer range<>) of signed(42 downto 0);
  type signed44_vector is array(integer range<>) of signed(43 downto 0);
  type signed45_vector is array(integer range<>) of signed(44 downto 0);
  type signed46_vector is array(integer range<>) of signed(45 downto 0);
  type signed47_vector is array(integer range<>) of signed(46 downto 0);
  type signed48_vector is array(integer range<>) of signed(47 downto 0);

  --! default standard signed vector type
  alias signed_vector is signed18_vector;

end package;
