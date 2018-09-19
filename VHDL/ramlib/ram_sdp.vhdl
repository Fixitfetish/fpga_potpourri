-------------------------------------------------------------------------------
--! @file       ram_sdp.vhdl
--! @author     Fixitfetish
--! @date       19/Sep/2018
--! @version    0.40
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Simple Dual Port RAM

entity ram_sdp is
  generic(
    --! Write port RAM data width
    WR_DATA_WIDTH      : positive;
    --! Read port RAM data width
    RD_DATA_WIDTH      : positive;
    --! RAM depth in number of write port data words
    WR_DEPTH           : positive;
    --! Use write port byte enables
    WR_USE_BYTE_ENABLE : boolean := false;
    --! Write port input pipeline registers, preferably RAM internal (at least one required!)
    WR_INPUT_REGS      : positive := 1;
    --! Read port input pipeline registers, preferably RAM internal (at least one required!)
    RD_INPUT_REGS      : positive := 1;
    --! Read port output pipeline registers, preferably RAM internal
    RD_OUTPUT_REGS     : natural := 1;
    --! RAM primitive type ("dist", "block" or "ultra")
    RAM_TYPE           : string := "block";
    --! Initialization file (without file extension)
    INIT_FILE          : string := ""
  );
  port(
    --! Write port clock
    wr_clk     : in  std_logic;
    --! Write port clock reset. Resets all input pipeline registers.
    wr_rst     : in  std_logic := '0';
    --! Write port clock enable
    wr_clk_en  : in  std_logic := '1';
    --! Write port enable
    wr_en      : in  std_logic := '0';
    --! Write port address
    wr_addr    : in  std_logic_vector;
    --! Write port data byte enable. Requires WR_USE_BYTE_ENABLE=true (optional)
    wr_be      : in  std_logic_vector(WR_DATA_WIDTH/8-1 downto 0) := (others=>'1');
    --! Write port data
    wr_data    : in  std_logic_vector(WR_DATA_WIDTH-1 downto 0);
    --! Read port clock
    rd_clk     : in  std_logic;
    --! Read port clock reset. Resets all input and output pipeline registers.
    rd_rst     : in  std_logic := '0';
    --! Read port clock enable
    rd_clk_en  : in  std_logic := '1';
    --! Read port (address) enable
    rd_en      : in  std_logic := '0';
    --! Read port address
    rd_addr    : in  std_logic_vector;
    --! Read port data
    rd_data    : out std_logic_vector(RD_DATA_WIDTH-1 downto 0);
    --! Read port data enable
    rd_data_en : out std_logic
  );
begin
  
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not (WR_USE_BYTE_ENABLE and (WR_DATA_WIDTH mod 8)/=0))
    report "Error " & ram_sdp'instance_name & ": When using byte enables the DATA_WIDTH must be multiple of 8."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
  
end entity;
