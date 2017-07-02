-------------------------------------------------------------------------------
--! @file       ieee_extension_types_2008.vhdl
--! @author     Fixitfetish
--! @date       17/Apr/2017
--! @version    0.11
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief This package provides types that are based on IEEE standard types.

package ieee_extension_types is

  --! General unconstrained unsigned vector type (preferably "to" direction)
  type unsigned_vector is array(integer range <>) of unsigned;

  --! General unconstrained signed vector type (preferably "to" direction)
  type signed_vector is array(integer range <>) of signed;

  subtype unsigned4_vector  is unsigned_vector(open)( 3 downto 0);
  subtype unsigned5_vector  is unsigned_vector(open)( 4 downto 0);
  subtype unsigned6_vector  is unsigned_vector(open)( 5 downto 0);
  subtype unsigned7_vector  is unsigned_vector(open)( 6 downto 0);
  subtype unsigned8_vector  is unsigned_vector(open)( 7 downto 0);
  subtype unsigned9_vector  is unsigned_vector(open)( 8 downto 0);
  subtype unsigned10_vector is unsigned_vector(open)( 9 downto 0);
  subtype unsigned11_vector is unsigned_vector(open)(10 downto 0);
  subtype unsigned12_vector is unsigned_vector(open)(11 downto 0);
  subtype unsigned13_vector is unsigned_vector(open)(12 downto 0);
  subtype unsigned14_vector is unsigned_vector(open)(13 downto 0);
  subtype unsigned15_vector is unsigned_vector(open)(14 downto 0);
  subtype unsigned16_vector is unsigned_vector(open)(15 downto 0);
  subtype unsigned17_vector is unsigned_vector(open)(16 downto 0);
  subtype unsigned18_vector is unsigned_vector(open)(17 downto 0);
  subtype unsigned19_vector is unsigned_vector(open)(18 downto 0);
  subtype unsigned20_vector is unsigned_vector(open)(19 downto 0);
  subtype unsigned21_vector is unsigned_vector(open)(20 downto 0);
  subtype unsigned22_vector is unsigned_vector(open)(21 downto 0);
  subtype unsigned23_vector is unsigned_vector(open)(22 downto 0);
  subtype unsigned24_vector is unsigned_vector(open)(23 downto 0);
  subtype unsigned25_vector is unsigned_vector(open)(24 downto 0);
  subtype unsigned26_vector is unsigned_vector(open)(25 downto 0);
  subtype unsigned27_vector is unsigned_vector(open)(26 downto 0);
  subtype unsigned28_vector is unsigned_vector(open)(27 downto 0);
  subtype unsigned29_vector is unsigned_vector(open)(28 downto 0);
  subtype unsigned30_vector is unsigned_vector(open)(29 downto 0);
  subtype unsigned31_vector is unsigned_vector(open)(30 downto 0);
  subtype unsigned32_vector is unsigned_vector(open)(31 downto 0);
  subtype unsigned33_vector is unsigned_vector(open)(32 downto 0);
  subtype unsigned34_vector is unsigned_vector(open)(33 downto 0);
  subtype unsigned35_vector is unsigned_vector(open)(34 downto 0);
  subtype unsigned36_vector is unsigned_vector(open)(35 downto 0);
  subtype unsigned37_vector is unsigned_vector(open)(36 downto 0);
  subtype unsigned38_vector is unsigned_vector(open)(37 downto 0);
  subtype unsigned39_vector is unsigned_vector(open)(38 downto 0);
  subtype unsigned40_vector is unsigned_vector(open)(39 downto 0);
  subtype unsigned41_vector is unsigned_vector(open)(40 downto 0);
  subtype unsigned42_vector is unsigned_vector(open)(41 downto 0);
  subtype unsigned43_vector is unsigned_vector(open)(42 downto 0);
  subtype unsigned44_vector is unsigned_vector(open)(43 downto 0);
  subtype unsigned45_vector is unsigned_vector(open)(44 downto 0);
  subtype unsigned46_vector is unsigned_vector(open)(45 downto 0);
  subtype unsigned47_vector is unsigned_vector(open)(46 downto 0);
  subtype unsigned48_vector is unsigned_vector(open)(47 downto 0);

  subtype signed4_vector  is signed_vector(open)( 3 downto 0);
  subtype signed5_vector  is signed_vector(open)( 4 downto 0);
  subtype signed6_vector  is signed_vector(open)( 5 downto 0);
  subtype signed7_vector  is signed_vector(open)( 6 downto 0);
  subtype signed8_vector  is signed_vector(open)( 7 downto 0);
  subtype signed9_vector  is signed_vector(open)( 8 downto 0);
  subtype signed10_vector is signed_vector(open)( 9 downto 0);
  subtype signed11_vector is signed_vector(open)(10 downto 0);
  subtype signed12_vector is signed_vector(open)(11 downto 0);
  subtype signed13_vector is signed_vector(open)(12 downto 0);
  subtype signed14_vector is signed_vector(open)(13 downto 0);
  subtype signed15_vector is signed_vector(open)(14 downto 0);
  subtype signed16_vector is signed_vector(open)(15 downto 0);
  subtype signed17_vector is signed_vector(open)(16 downto 0);
  subtype signed18_vector is signed_vector(open)(17 downto 0);
  subtype signed19_vector is signed_vector(open)(18 downto 0);
  subtype signed20_vector is signed_vector(open)(19 downto 0);
  subtype signed21_vector is signed_vector(open)(20 downto 0);
  subtype signed22_vector is signed_vector(open)(21 downto 0);
  subtype signed23_vector is signed_vector(open)(22 downto 0);
  subtype signed24_vector is signed_vector(open)(23 downto 0);
  subtype signed25_vector is signed_vector(open)(24 downto 0);
  subtype signed26_vector is signed_vector(open)(25 downto 0);
  subtype signed27_vector is signed_vector(open)(26 downto 0);
  subtype signed28_vector is signed_vector(open)(27 downto 0);
  subtype signed29_vector is signed_vector(open)(28 downto 0);
  subtype signed30_vector is signed_vector(open)(29 downto 0);
  subtype signed31_vector is signed_vector(open)(30 downto 0);
  subtype signed32_vector is signed_vector(open)(31 downto 0);
  subtype signed33_vector is signed_vector(open)(32 downto 0);
  subtype signed34_vector is signed_vector(open)(33 downto 0);
  subtype signed35_vector is signed_vector(open)(34 downto 0);
  subtype signed36_vector is signed_vector(open)(35 downto 0);
  subtype signed37_vector is signed_vector(open)(36 downto 0);
  subtype signed38_vector is signed_vector(open)(37 downto 0);
  subtype signed39_vector is signed_vector(open)(38 downto 0);
  subtype signed40_vector is signed_vector(open)(39 downto 0);
  subtype signed41_vector is signed_vector(open)(40 downto 0);
  subtype signed42_vector is signed_vector(open)(41 downto 0);
  subtype signed43_vector is signed_vector(open)(42 downto 0);
  subtype signed44_vector is signed_vector(open)(43 downto 0);
  subtype signed45_vector is signed_vector(open)(44 downto 0);
  subtype signed46_vector is signed_vector(open)(45 downto 0);
  subtype signed47_vector is signed_vector(open)(46 downto 0);
  subtype signed48_vector is signed_vector(open)(47 downto 0);

end package;
