-------------------------------------------------------------------------------
--! @file       prbs_3gpp.vhdl
--! @author     Fixitfetish
--! @date       04/May/2019
--! @version    0.40
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
library siglib;

--! @brief Generation of Pseudo Random Bit Sequence (Gold) according to 3GPP TS 36.211
--!
entity prbs_3gpp is
generic (
  --! @brief Number of bit shifts per cycle.
  SHIFTS_PER_CYCLE : positive := 1;
  --! @brief In the default request mode a valid value is output with a fixed delay after the request.
  --! In acknowledge mode the output always shows a valid next value 
  --! which must be acknowledged to get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := false;
  --! @brief Number required output bits.
  OUTPUT_WIDTH : positive := 1;
  --! @brief Enable additional output register. Recommended default is true.
  --! When enabled the load to output delay and request to output delay is 2 cycles.
  OUTPUT_REG : boolean := true
);
port (
  --! Clock
  clk        : in  std_logic;
  --! Initialize/load shift register with seed
  load       : in  std_logic;
  --! Request / Acknowledge
  req_ack    : in  std_logic := '1';
  --! Initial contents of X2 shift register after reset.
  seed       : in  std_logic_vector(30 downto 0);
  --! Shift register output, right aligned. Is shifted right by BITS_PER_CYCLE bits in each cycle.
  dout       : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  --! Shift register output valid
  dout_vld   : out std_logic;
  --! First output value after loading
  dout_first : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of prbs_3gpp is

  constant X1_TAPS : integer_vector := (31,28);
  constant X2_TAPS : integer_vector := (31,30,29,28);

  constant X1_SEED : std_logic_vector(30 downto 0) := (0=>'1', others=>'0');

  -- shift registers
  signal x1, x2, dout_i : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal x1_vld, x2_vld, dout_vld_i : std_logic;
  signal x1_first, x2_first, dout_first_i : std_logic;
  signal req_ack_i : std_logic;

begin

  i_x1 : entity siglib.lfsr
  generic map(
    TAPS             => X1_TAPS,
    FIBONACCI        => true,
    SHIFTS_PER_CYCLE => SHIFTS_PER_CYCLE,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => 1600, -- Nc
    OFFSET_LOGIC     => "input", -- note: constant seed!
    TRANSFORM_SEED   => false,
    OUTPUT_WIDTH     => OUTPUT_WIDTH,
    OUTPUT_REG       => false -- local output register, see below
  )
  port map (
    clk          => clk,
    load         => load,
    req_ack      => req_ack_i,
    seed         => X1_SEED, -- constant seed
    dout         => x1,
    dout_vld_rdy => x1_vld,
    dout_first   => x1_first
  );

  i_x2 : entity siglib.lfsr
  generic map(
    TAPS             => X2_TAPS,
    FIBONACCI        => true,
    SHIFTS_PER_CYCLE => SHIFTS_PER_CYCLE,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => 1600, -- Nc
    OFFSET_LOGIC     => "output",
    TRANSFORM_SEED   => false,
    OUTPUT_WIDTH     => OUTPUT_WIDTH,
    OUTPUT_REG       => false -- local output register, see below
  )
  port map (
    clk          => clk,
    load         => load,
    req_ack      => req_ack_i,
    seed         => seed,
    dout         => x2,
    dout_vld_rdy => x2_vld,
    dout_first   => x2_first
  );

  dout_i <= x1 xor x2;
  dout_vld_i <= x1_vld and x2_vld;
  dout_first_i <= x1_first and x2_first;


  -- output direct, without output register
  g_oreg_off : if not OUTPUT_REG generate
    req_ack_i <= req_ack;
    dout <= dout_i;
    dout_vld <= dout_vld_i;
    dout_first <= dout_first_i;
  end generate;

  -- output register - request mode
  g_oreg_req : if OUTPUT_REG and not ACKNOWLEDGE_MODE generate
    req_ack_i <= req_ack;
    dout <= dout_i when rising_edge(clk);
    dout_vld <= dout_vld_i when rising_edge(clk);
    dout_first <= dout_first_i when rising_edge(clk);
  end generate;

  -- output register - acknowledge mode
  g_oreg_ack : if OUTPUT_REG and ACKNOWLEDGE_MODE generate
    signal rdy : std_logic;
  begin
    rdy <= not load when rising_edge(clk);
    req_ack_i <= dout_first_i or (rdy and req_ack);
    p : process(clk)
    begin
      if rising_edge(clk) then
        if load='1' then
          dout_first <= '0';
          dout <= (dout_i'range=>'-');
        elsif dout_first_i='1' or req_ack_i='1' then 
          dout_first <= dout_first_i;
          dout <= dout_i;
        end if;
      end if;
    end process;
    dout_vld <= rdy;
  end generate;


end architecture;
