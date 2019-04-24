-------------------------------------------------------------------------------
--! @file       prbs_3gpp.vhdl
--! @author     Fixitfetish
--! @date       24/Apr/2019
--! @version    0.20
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
  --! @brief Number of shifts/bits per cycle. Cannot exceed the length of the shift register.
  BITS_PER_CYCLE : positive range 1 to 31 := 1;
  --! @brief In the default request mode one valid value is output one cycle after the request.
  --! In acknowledge mode the output always shows the next value which must be acknowledged to
  --! get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := false;
  --! Enable output register
  OUTPUT_REG : boolean := false
);
port (
  --! Clock
  clk       : in  std_logic;
  --! Initialize/load shift register with seed
  load      : in  std_logic;
  --! Request / Acknowledge
  req_ack   : in  std_logic := '1';
  --! Initial contents of X2 shift register after reset.
  seed      : in  std_logic_vector(30 downto 0);
  --! Shift register output, right aligned. Is shifted right by BITS_PER_CYCLE bits in each cycle.
  dout      : out std_logic_vector(30 downto 0);
  --! Shift register output valid
  dout_vld  : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of prbs_3gpp is

  -- shift registers
  signal x1, x2 : std_logic_vector(30 downto 0);
  signal x1_vld, x2_vld : std_logic;

begin

  i_x1 : entity siglib.lfsr
  generic map(
    TAPS             => (31,28),
    FIBONACCI        => true,
    BITS_PER_CYCLE   => BITS_PER_CYCLE,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => 1600, -- Nc
    OFFSET_AT_OUTPUT => false
  )
  port map (
    clk        => clk,
    load       => load,
    req_ack    => req_ack,
    seed       => (0=>'1', others=>'0'), -- constant seed
    dout       => x1,
    dout_vld   => x1_vld
  );

  i_x2 : entity siglib.lfsr
  generic map(
    TAPS             => (31,30,29,28),
    FIBONACCI        => true,
    BITS_PER_CYCLE   => BITS_PER_CYCLE,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => 1600, -- Nc
    OFFSET_AT_OUTPUT => false
  )
  port map (
    clk        => clk,
    load       => load,
    req_ack    => req_ack,
    seed       => seed,
    dout       => x2,
    dout_vld   => x2_vld
  );

  -- final output
  g_oreg_off : if not OUTPUT_REG generate
    dout <= x1 xor x2;
    dout_vld <= x1_vld and x2_vld;
  end generate;

  g_oreg_on : if OUTPUT_REG generate
    dout <= x1 xor x2 when rising_edge(clk);
    dout_vld <= x1_vld and x2_vld when rising_edge(clk);
  end generate;

end architecture;
