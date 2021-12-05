-------------------------------------------------------------------------------
--! @file       ieee_extension_types_2008.vhdl
--! @author     Fixitfetish
--! @date       23/May/2019
--! @version    0.20
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief This package provides types that are based on IEEE standard types.
--!
package ieee_extension_types is

  --! General unconstrained unsigned vector type (preferably "to" direction)
  type unsigned_vector is array(integer range <>) of unsigned;

  --! General unconstrained signed vector type (preferably "to" direction)
  type signed_vector is array(integer range <>) of signed;

  --! General unconstrained std_logic_vector array type 
  type slv_array is array(integer range <>) of std_logic_vector;

--  type slv16_array is array(integer range<>) of std_logic_vector(15 downto 0);
--  type slv32_array is array(integer range<>) of std_logic_vector(31 downto 0);

  
  subtype unsigned2_vector  is unsigned_vector(open)( 1 downto 0);
  subtype unsigned3_vector  is unsigned_vector(open)( 2 downto 0);
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
  subtype unsigned49_vector is unsigned_vector(open)(48 downto 0);
  subtype unsigned50_vector is unsigned_vector(open)(49 downto 0);

  subtype signed2_vector  is signed_vector(open)( 1 downto 0);
  subtype signed3_vector  is signed_vector(open)( 2 downto 0);
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
  subtype signed49_vector is signed_vector(open)(48 downto 0);
  subtype signed50_vector is signed_vector(open)(49 downto 0);

  subtype slv1_array  is slv_array(open)( 0 downto 0);
  subtype slv2_array  is slv_array(open)( 1 downto 0);
  subtype slv3_array  is slv_array(open)( 2 downto 0);
  subtype slv4_array  is slv_array(open)( 3 downto 0);
  subtype slv5_array  is slv_array(open)( 4 downto 0);
  subtype slv6_array  is slv_array(open)( 5 downto 0);
  subtype slv7_array  is slv_array(open)( 6 downto 0);
  subtype slv8_array  is slv_array(open)( 7 downto 0);
  subtype slv9_array  is slv_array(open)( 8 downto 0);
  subtype slv10_array is slv_array(open)( 9 downto 0);
  subtype slv11_array is slv_array(open)(10 downto 0);
  subtype slv12_array is slv_array(open)(11 downto 0);
  subtype slv13_array is slv_array(open)(12 downto 0);
  subtype slv14_array is slv_array(open)(13 downto 0);
  subtype slv15_array is slv_array(open)(14 downto 0);
  subtype slv16_array is slv_array(open)(15 downto 0);
  subtype slv17_array is slv_array(open)(16 downto 0);
  subtype slv18_array is slv_array(open)(17 downto 0);
  subtype slv19_array is slv_array(open)(18 downto 0);
  subtype slv20_array is slv_array(open)(19 downto 0);
  subtype slv21_array is slv_array(open)(20 downto 0);
  subtype slv22_array is slv_array(open)(21 downto 0);
  subtype slv23_array is slv_array(open)(22 downto 0);
  subtype slv24_array is slv_array(open)(23 downto 0);
  subtype slv25_array is slv_array(open)(24 downto 0);
  subtype slv26_array is slv_array(open)(25 downto 0);
  subtype slv27_array is slv_array(open)(26 downto 0);
  subtype slv28_array is slv_array(open)(27 downto 0);
  subtype slv29_array is slv_array(open)(28 downto 0);
  subtype slv30_array is slv_array(open)(29 downto 0);
  subtype slv31_array is slv_array(open)(30 downto 0);
  subtype slv32_array is slv_array(open)(31 downto 0);
  subtype slv33_array is slv_array(open)(32 downto 0);
  subtype slv34_array is slv_array(open)(33 downto 0);
  subtype slv35_array is slv_array(open)(34 downto 0);
  subtype slv36_array is slv_array(open)(35 downto 0);
  subtype slv37_array is slv_array(open)(36 downto 0);
  subtype slv38_array is slv_array(open)(37 downto 0);
  subtype slv39_array is slv_array(open)(38 downto 0);
  subtype slv40_array is slv_array(open)(39 downto 0);
  subtype slv41_array is slv_array(open)(40 downto 0);
  subtype slv42_array is slv_array(open)(41 downto 0);
  subtype slv43_array is slv_array(open)(42 downto 0);
  subtype slv44_array is slv_array(open)(43 downto 0);
  subtype slv45_array is slv_array(open)(44 downto 0);
  subtype slv46_array is slv_array(open)(45 downto 0);
  subtype slv47_array is slv_array(open)(46 downto 0);
  subtype slv48_array is slv_array(open)(47 downto 0);
  subtype slv49_array is slv_array(open)(48 downto 0);
  subtype slv50_array is slv_array(open)(49 downto 0);
  subtype slv51_array is slv_array(open)(50 downto 0);
  subtype slv52_array is slv_array(open)(51 downto 0);
  subtype slv53_array is slv_array(open)(52 downto 0);
  subtype slv54_array is slv_array(open)(53 downto 0);
  subtype slv55_array is slv_array(open)(54 downto 0);
  subtype slv56_array is slv_array(open)(55 downto 0);
  subtype slv57_array is slv_array(open)(56 downto 0);
  subtype slv58_array is slv_array(open)(57 downto 0);
  subtype slv59_array is slv_array(open)(58 downto 0);
  subtype slv60_array is slv_array(open)(59 downto 0);
  subtype slv61_array is slv_array(open)(60 downto 0);
  subtype slv62_array is slv_array(open)(61 downto 0);
  subtype slv63_array is slv_array(open)(62 downto 0);
  subtype slv64_array is slv_array(open)(63 downto 0);

end package;
