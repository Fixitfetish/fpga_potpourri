-------------------------------------------------------------------------------
-- @file       xilinx_output_logic.vhdl
-- @author     Fixitfetish
-- @date       15/Sep/2024
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

-- DSP cell output logic that supports right shift, rounding,
-- clipping/saturation and additional pipelining.
--
-- Rounding: 'nearest' (half-up) of result output.
-- If enabled, i.e. dsp_out_rnd is connected and not static '0',
-- then rounding in logic is implemented and it is recommended
-- to have at least one pipeline register (after rounding and clipping).
--
-- VHDL Instantiation Template:
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
-- I1 : xilinx_output_logic
-- generic map(
--   PIPELINE_STAGES    => integer,  -- number of pipeline registers
--   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--   OUTPUT_CLIP        => boolean,  -- enable clipping
--   OUTPUT_OVERFLOW    => boolean,  -- enable overflow detection
--   NUM_AUXILIARY_BITS => positive  -- number of user defined auxiliary bits
-- )
-- port map (
--   clk         => in  std_logic, -- clock
--   rst         => in  std_logic, -- reset
--   clkena      => in  std_logic, -- clock enable
--   dsp_out     => in  signed,    -- input data
--   dsp_out_vld => in  std_logic, -- input valid
--   dsp_out_ovf => in  std_logic, -- input overflow flag
--   dsp_out_rnd => in  std_logic, -- rounding required
--   dsp_out_aux => in  std_logic_vector, -- input auxiliary
--   result      => out signed,    -- output data
--   result_vld  => out std_logic, -- output valid
--   result_ovf  => out std_logic, -- output overflow
--   result_rst  => out std_logic, -- output reset
--   result_aux  => out std_logic_vector -- output auxiliary
-- );
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
entity xilinx_output_logic is
generic (
  -- Number of additional logic pipeline registers after DSP cell output
  -- register. At least one pipeline register is recommended when logic for 
  -- rounding, clipping and/or overflow detection is enabled. 
  -- Negative values are allowed intentionally. For values <=0 just logic
  -- without any pipeline registers is generated.
  PIPELINE_STAGES : integer := 1;
  -- Number of bits by which the DSP output is shifted right.
  OUTPUT_SHIFT_RIGHT : natural := 0;
  -- Enable clipping when right shifted result exceeds output range.
  OUTPUT_CLIP : boolean := true;
  -- Enable overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := true;
  -- Number of user-defined auxiliary bits. Can be useful for e.g. last and/or first flags.
  NUM_AUXILIARY_BITS : positive := 1
);
port (
  -- Clock
  clk         : in  std_logic;
  -- Synchronous reset input, should be time-aligned to DSP_OUT input ports for correct reset pipelining (optional)
  rst         : in  std_logic := '0';
  -- Clock enable
  clkena      : in  std_logic := '1';
  -- DSP cell output data
  dsp_out     : in  signed;
  -- Valid signal for DSP output data, high-active
  dsp_out_vld : in  std_logic;
  -- DSP output data overflow, high-active
  dsp_out_ovf : in  std_logic := '0';
  -- DSP cell output data requires rounding (because rounding was not possible within DSP cell)
  dsp_out_rnd : in  std_logic := '0';
  -- Optional input of user-defined auxiliary bits
  dsp_out_aux : in  std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0) := (others=>'0');
  -- Pipelined DSP cell output with optional right-shift, rounding and clipping.
  result      : out signed;
  -- Valid signal for result output, high-active
  result_vld  : out std_logic;
  -- Result output overflow/clipping detection
  result_ovf  : out std_logic;
  -- Pipelined result output reset, independent of CLKENA
  result_rst  : out std_logic;
  -- Optional output of delayed auxiliary user-defined bits (same length as auxiliary input)
  result_aux  : out std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0)
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (OUTPUT_SHIFT_RIGHT<dsp_out'length)
    report "ERROR in " & xilinx_output_logic'INSTANCE_NAME & ": " & 
           "Number of right shifts shall not exceed data input width."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of xilinx_output_logic is

  -- derived constants
  constant SHIFTED_WIDTH : natural := dsp_out'length - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;
  constant PIPELINE_REGS : natural := MAXIMUM(0,PIPELINE_STAGES); -- ensure >=0

  -- right shifted DSP cell output
  signal dsp_out_shifted : signed(SHIFTED_WIDTH-1 downto 0) := (others=>'0');

  -- result register pipeline
  type r_result is
  record
    rst : std_logic;
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
    aux : std_logic_vector(dsp_out_aux'range);
  end record;
  type array_result is array(integer range <>) of r_result;

  -- signal r0 shall NOT have dont_touch attribute to allow optimizations
  signal r0 : r_result;

  -- signal r is meant for output pipelining, even multiple stages over larger distances
  signal r : array_result(0 to PIPELINE_REGS) := (others=>(rst=>'0',dat=>(others=>'-'),vld|ovf=>'0',aux=>(others=>'0')));
  attribute dont_touch : string;
  attribute dont_touch of r : signal is "true"; --"true|yes" or "false|no"
  attribute shreg_extract : string;
  attribute shreg_extract of r : signal is "no";

begin

  -- NOTE: Rounding logic is optimized out when dsp_out_rnd is not connected or static '0'.
  dsp_out_shifted <= 
    RESIZE(SHIFT_RIGHT_ROUND(dsp_out, OUTPUT_SHIFT_RIGHT),SHIFTED_WIDTH) when (OUTPUT_SHIFT_RIGHT=0 or dsp_out_rnd='0') else
    RESIZE(SHIFT_RIGHT_ROUND(dsp_out, OUTPUT_SHIFT_RIGHT, nearest),SHIFTED_WIDTH);

  -- resize and clipping
  p_out : process(dsp_out_shifted, dsp_out_vld, dsp_out_ovf, dsp_out_aux)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>dsp_out_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    r0.vld <= dsp_out_vld;
    r0.aux <= dsp_out_aux;
    r0.dat <= v_dat;
    if OUTPUT_OVERFLOW then
      -- enable output overflow detection only for valid output data
      r0.ovf <= (v_ovf or dsp_out_ovf) and dsp_out_vld;
    else
      -- just pass through incoming overflow bit
      r0.ovf <= dsp_out_ovf and dsp_out_vld;
    end if;
  end process;

  r0.rst <= rst;

  p_pipe : process(clk,r0)
  begin 
    r(0) <= r0;
    if rising_edge(clk) then
      if clkena='1' then
        for i in 1 to PIPELINE_REGS loop
          -- only first pipeline stage with data gating
          -- * only new valid data to output, required for comparability with other implementations
          -- * similar as it's done for the DSP internal P output register
          -- * reduce toggle rates and save power
          if i=1 then
            if r0.vld='1' then
              r(i).dat <= r0.dat;
            end if;
            r(i).ovf <= r0.ovf;
            r(i).vld <= r0.vld;
            r(i).aux <= r0.aux;
            r(i).rst <= r0.rst;
          else
            r(i).dat <= r(i-1).dat;
            r(i).ovf <= r(i-1).ovf;
            r(i).vld <= r(i-1).vld;
            r(i).aux <= r(i-1).aux;
            r(i).rst <= r(i-1).rst;
          end if;
        end loop;
      end if;
    end if;
  end process;

  -- map result to output port
  result     <= r(PIPELINE_REGS).dat;
  result_vld <= r(PIPELINE_REGS).vld;
  result_aux <= r(PIPELINE_REGS).aux;
  result_ovf <= r(PIPELINE_REGS).ovf;
  result_rst <= r(PIPELINE_REGS).rst;

end architecture;
