-------------------------------------------------------------------------------
--! @file       ieee_extension_types_2008.vhdl
--! @author     Fixitfetish
--! @date       17/Apr/2017
--! @version    0.11
--! @copyright  MIT License
--! @note       VHDL-2008
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
  subtype unsigned6_vector  is unsigned_vector(open)( 5 downto 0);
  subtype unsigned8_vector  is unsigned_vector(open)( 7 downto 0);
  subtype unsigned10_vector is unsigned_vector(open)( 9 downto 0);
  subtype unsigned12_vector is unsigned_vector(open)(11 downto 0);
  subtype unsigned14_vector is unsigned_vector(open)(13 downto 0);
  subtype unsigned16_vector is unsigned_vector(open)(15 downto 0);
  subtype unsigned18_vector is unsigned_vector(open)(17 downto 0);
  subtype unsigned20_vector is unsigned_vector(open)(19 downto 0);
  subtype unsigned22_vector is unsigned_vector(open)(21 downto 0);
  subtype unsigned24_vector is unsigned_vector(open)(23 downto 0);
  subtype unsigned26_vector is unsigned_vector(open)(25 downto 0);
  subtype unsigned28_vector is unsigned_vector(open)(27 downto 0);
  subtype unsigned30_vector is unsigned_vector(open)(29 downto 0);
  subtype unsigned32_vector is unsigned_vector(open)(31 downto 0);
  subtype unsigned34_vector is unsigned_vector(open)(33 downto 0);
  subtype unsigned36_vector is unsigned_vector(open)(35 downto 0);
  subtype unsigned38_vector is unsigned_vector(open)(37 downto 0);
  subtype unsigned40_vector is unsigned_vector(open)(39 downto 0);
  subtype unsigned42_vector is unsigned_vector(open)(41 downto 0);
  subtype unsigned44_vector is unsigned_vector(open)(43 downto 0);
  subtype unsigned46_vector is unsigned_vector(open)(45 downto 0);
  subtype unsigned48_vector is unsigned_vector(open)(47 downto 0);

  subtype signed4_vector  is signed_vector(open)( 3 downto 0);
  subtype signed6_vector  is signed_vector(open)( 5 downto 0);
  subtype signed8_vector  is signed_vector(open)( 7 downto 0);
  subtype signed10_vector is signed_vector(open)( 9 downto 0);
  subtype signed12_vector is signed_vector(open)(11 downto 0);
  subtype signed14_vector is signed_vector(open)(13 downto 0);
  subtype signed16_vector is signed_vector(open)(15 downto 0);
  subtype signed18_vector is signed_vector(open)(17 downto 0);
  subtype signed20_vector is signed_vector(open)(19 downto 0);
  subtype signed22_vector is signed_vector(open)(21 downto 0);
  subtype signed24_vector is signed_vector(open)(23 downto 0);
  subtype signed26_vector is signed_vector(open)(25 downto 0);
  subtype signed28_vector is signed_vector(open)(27 downto 0);
  subtype signed30_vector is signed_vector(open)(29 downto 0);
  subtype signed32_vector is signed_vector(open)(31 downto 0);
  subtype signed34_vector is signed_vector(open)(33 downto 0);
  subtype signed36_vector is signed_vector(open)(35 downto 0);
  subtype signed38_vector is signed_vector(open)(37 downto 0);
  subtype signed40_vector is signed_vector(open)(39 downto 0);
  subtype signed42_vector is signed_vector(open)(41 downto 0);
  subtype signed44_vector is signed_vector(open)(43 downto 0);
  subtype signed46_vector is signed_vector(open)(45 downto 0);
  subtype signed48_vector is signed_vector(open)(47 downto 0);

end package;
