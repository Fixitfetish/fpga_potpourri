-------------------------------------------------------------------------------
--! @file       ram_sdp.vhdl
--! @author     Fixitfetish
--! @date       22/Sep/2018
--! @version    0.50
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

--! @brief Simple Dual Port (SDP) RAM
--! 
--! In contrast to a True Dual Port (TDP) RAM, the SDP RAM has one write-only port and
--! one read-only port, both ports with independent address and clock.
--! In some cases a SDP RAM can save FPGA resources, e.g. high data width but low depth.
--! The resource saving depends on the FPGA type and vendor.
--! Hence, preferably use SDP instead of TDP RAM whenever possible.
--!
--! Notes
--! * Write and read data width must always have a ratio which is a power of 2.
--! * The address inputs are internally resized to the actually required address width.

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
    --! Write port clock enable (optional)
    wr_clk_en  : in  std_logic := '1';
    --! Write port enable
    wr_en      : in  std_logic := '0';
    --! Write port address (maximum width depends on RAM depth)
    wr_addr    : in  std_logic_vector;
    --! Write port data byte enable. Requires WR_USE_BYTE_ENABLE=true (optional)
    wr_be      : in  std_logic_vector(WR_DATA_WIDTH/8-1 downto 0) := (others=>'1');
    --! Write port data
    wr_data    : in  std_logic_vector(WR_DATA_WIDTH-1 downto 0);
    --! Read port clock
    rd_clk     : in  std_logic;
    --! Read port clock reset. Resets all input and output pipeline registers.
    rd_rst     : in  std_logic := '0';
    --! Read port clock enable (optional)
    rd_clk_en  : in  std_logic := '1';
    --! Read port (address) input enable
    rd_en      : in  std_logic := '0';
    --! Read port address (maximum width depends on RAM depth)
    rd_addr    : in  std_logic_vector;
    --! Read port data
    rd_data    : out std_logic_vector(RD_DATA_WIDTH-1 downto 0);
    --! Read port data enable (delayed rd_en signal)
    rd_data_en : out std_logic
  );
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  constant DATA_WIDTH_RATIO_LOG2 : real := log2(real(WR_DATA_WIDTH)/real(RD_DATA_WIDTH));
  
  begin

  assert (not (WR_USE_BYTE_ENABLE and (WR_DATA_WIDTH mod 8)/=0))
    report "Error " & ram_sdp'instance_name & ": When using byte enables the DATA_WIDTH must be multiple of 8."
    severity failure;
  assert (not (RD_DATA_WIDTH/=WR_DATA_WIDTH and abs(round(DATA_WIDTH_RATIO_LOG2)-DATA_WIDTH_RATIO_LOG2)>1.0e-6 ))
    report "Error " & ram_sdp'instance_name & ": The ratio of write and read data width is not a power of 2."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
