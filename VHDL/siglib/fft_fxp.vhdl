-------------------------------------------------------------------------------
--! @file       fft_fxp.vhdl
--! @author     Fixitfetish
--! @date       28/Jan/2018
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief Fix-point FFT (forward / inverse)
--!
--! Two FFT types are supported:
--! * STREAMING : continuous data processing with short transform time but requires
--!   comparatively many FPGA resources.
--! * BURST : burst-wise data processing with rather long transform time but
--!   requires comparatively few FPGA resources.
--! 
--! !!! First ideas only. Does this approach make sense? 
--!
--! Requirements
--! * shall be AXI4-Streaming compatible
--! * Altera/Xilinx compatible
--! * time-multiplex support for multiple independent data streams
--! * flexible input/output data width
--! * scaling , shifting after stages  # TODO

entity fft_fxp is
  generic (
    --! @brief LOG2 of FFT size, e.g. 11 means 2**11 = 2048. If the FFT size is dynamically
    --! reconfigurable the value defines the maximum supported FFT size.
    FFT_SIZE_LOG2 : positive;
    --! FFT type can be BURST or STREAMING.
    STREAMING : boolean;
    --! Data frame ID range is 0 to 2**FRAME_ID_WIDTH-1 (only required for time-multiplexed channels)
    FRAME_ID_WIDTH : positive := 1
  );
  port (
    --! Standard system clock
    clk         : in  std_logic;
    --! Synchronous Reset
    rst         : in  std_logic;
    --! Is FFT ready to receive new configuration ? 
    cfg_ready   : out std_logic;
    --! Set new configuration, i.e. direction, scaling, etc.
    cfg_valid   : in  std_logic;
    --! FFT direction, forward='0', inverse='1', default is '0' 
    cfg_inverse : in  std_logic := '0';
    --! Is FFT ready to receive input data ? 
    din_ready   : out std_logic;
    --! @brief Input FFT frame identifier, must be constant for all data values of a frame 
    --! (only relevant in case of time-multiplexed channels)
    din_id      : in  unsigned(FRAME_ID_WIDTH-1 downto 0) := (others=>'0');
    --! Marker for first input value of FFT frame
    din_first   : in  std_logic;
    --! Marker for last input value of FFT frame
    din_last    : in  std_logic;
    --! FFT input data in natural order including valid signal
    din_data    : in  cplx;
    --! Ready to accept FFT output data ?
    dout_ready  : in  std_logic;
    --! @brief Output FFT frame identifier, is constant for all data values of a frame 
    --! (only relevant in case of time-multiplexed channels)
    dout_id     : out unsigned(FRAME_ID_WIDTH-1 downto 0);
    --! Marker for first output value of FFT frame
    dout_first  : out std_logic;
    --! Marker for last output value of FFT frame
    dout_last   : out std_logic;
    --! output data index (0 to NFFT-1)
    dout_index  : out unsigned(FFT_SIZE_LOG2-1 downto 0);
    --! FFT output data including valid and overflow signal
    dout_data   : out cplx
  );
end entity;
