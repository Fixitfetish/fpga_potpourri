-------------------------------------------------------------------------------
-- @file       delay_flex.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- Synchronous delay block with dynamically configurable delay based on SR-LUTs (SRLs).
-- Very resource efficient for maximum delay of 16,32,etc.
--
-- VHDL Instantiation Template:
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
-- I1 : delay_flex
-- generic map (
--   MAX_DELAY       => positive, -- Maximum delay in number of clock cycles (excluding optional data output register)
--   DLY_INPUT_REG   => boolean,  -- Enable additional DLY configuration input register in logic (optional)
--   DATA_OUTPUT_REG => boolean   -- Enable additional data output pipeline register in logic (optional)
-- )
-- port map (
--   clk      => in  std_logic,
--   rst      => in  std_logic (optional),
--   ce       => in  std_logic (optional),
--   dly      => in  integer,
--   din      => in  std_logic_vector,
--   din_vld  => in  std_logic (optional),
--   dout     => out std_logic_vector,
--   dout_vld => out std_logic (optional)
-- );
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
entity delay_flex is
generic (
  -- Maximum delay in number of clock cycles (excluding optional data output pipeline register)
  MAX_DELAY : positive;
  -- Enable additional DLY configuration input pipeline register in logic (optional)
  DLY_INPUT_REG : boolean := false;
  -- Enable additional data output pipeline register in logic (optional)
  DATA_OUTPUT_REG : boolean := false
);
port (
  -- Clock 
  clk      : in  std_logic;
  -- Synchronous reset (optional), flush VLD pipeline (MAX_DELAY cycles required)
  rst      : in  std_logic := '0';
  -- Clock enable (optional)
  ce       : in  std_logic := '1';
  -- Delay configuration, 0,..,MAX_DELAY-1 = 1,..,MAX_DELAY cycles (excluding optional data output register)
  dly      : in  integer range 0 to MAX_DELAY-1;
  -- Data input
  din      : in  std_logic_vector;
  -- Data input valid (optional)
  din_vld  : in  std_logic := '0';
  -- Data output
  dout     : out std_logic_vector;
  -- Data output valid (optional)
  dout_vld : out std_logic
);
end entity;

---------------------------------------------------------------------------------------------------

architecture rtl of delay_flex is

  attribute dont_touch : string;
  attribute shreg_extract : string;

  signal dly_i : integer range 0 to MAX_DELAY-1;

  -- SR signals
  type a_din is array(integer range <>) of din'subtype;
  signal sr : a_din(0 to MAX_DELAY-1) := (others=>(others=>'-'));
  signal sr_vld : std_logic_vector(0 to MAX_DELAY-1) := (others=>'0');
  attribute shreg_extract of sr : signal is "yes";
  attribute shreg_extract of sr_vld : signal is "yes";

  -- SR-LUT multiplexer output
  signal sr_out : din'subtype;
  signal sr_vld_out : std_logic;

begin

  -- optional delay configuration input pipeline register (for timing)
  g_dly_ireg: if DLY_INPUT_REG generate
    signal dly_q : integer range 0 to MAX_DELAY-1;
    attribute dont_touch of dly_q : signal is "true";
  begin
    dly_q <= dly when rising_edge(clk);
    dly_i <= dly_q;
  else generate
    dly_i <= dly;
  end generate;

  -- Data SR-LUT
  p_sr : process(clk)
  begin
    if rising_edge(clk) then
      if ce='1' then
        sr(1 to sr'high) <= sr(0 to sr'high-1);
        sr(0) <= din;
      end if;
    end if;
  end process;

  -- optional valid SR-LUT
  p_sr_vld : process(clk)
  begin
    if rising_edge(clk) then
      -- NOTE: flush VLD pipeline during reset
      if ce='1' or rst='1' then
        sr_vld(1 to sr_vld'high) <= sr_vld(0 to sr_vld'high-1);
        sr_vld(0) <= din_vld and not rst;
      end if;
    end if;
  end process;

  -- SRL multiplexer
  sr_out <= sr(dly_i);
  sr_vld_out <= sr_vld(dly_i);

  -- optional output pipeline register (for timing)
  g_oreg: if DATA_OUTPUT_REG generate
    signal dout_q : sr_out'subtype;
    signal dout_vld_q : sr_vld_out'subtype;
    attribute dont_touch of dout_q : signal is "true";
    attribute dont_touch of dout_vld_q : signal is "true";
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if ce='1' then
          dout_q <= sr_out;
          dout_vld_q <= sr_vld_out;
        end if;
        if rst='1' then
          dout_vld_q <= '0';
        end if;
      end if;
    end process; 
    dout <= dout_q;
    dout_vld <= dout_vld_q;
  else generate
    dout <= sr_out;
    dout_vld <= sr_vld_out;
  end generate;

end;
