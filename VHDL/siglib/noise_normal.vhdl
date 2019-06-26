-------------------------------------------------------------------------------
--! @file       noise_normal.vhdl
--! @author     Fixitfetish
--! @date       26/Jun/2019
--! @version    0.30
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
--library baselib;
--  use baselib.pipereg_pkg.all;
library siglib;
  use siglib.lfsr_pkg.all;

--! @brief White Gaussian Noise Generator.
--!
--! The mean is zero and the absolute peak value PVAL is 2**(RESOLUTION-1).
--! The peak power is always 0 dBfs.
--!
--! In this preliminary first version the average noise power is -15dBfs.
--! Some parameters are still fixed and/or the range is very limited.
--! Further improvements are planned already.
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : noise_normal
--! generic map (
--!   RESOLUTION       => integer, -- Output resolution in number of bits
--!   ACKNOWLEDGE_MODE => boolean,
--!   INSTANCE_IDX     => integer
--! )
--! port map (
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- synchronous reset
--!   req_ack    => in  std_logic, 
--!   dout       => out signed,
--!   dout_vld   => out std_logic,
--!   dout_first => out std_logic,
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity noise_normal is
generic (
  --! Output resolution in number of bits
  RESOLUTION : positive range 12 to 20;
  --! @brief In the default request mode a valid value is output with a fixed delay after the request.
  --! In acknowledge mode (first word fall through) the output always shows the next value 
  --! which must be acknowledged to get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := false;
  --! @brief The optional instance index has an influence on the seed and the number
  --! of bit shifts per cycles to avoid noise correlation between multiple instances.
  INSTANCE_IDX : integer range 0 to 39 := 0
);
port (
  --! Clock
  clk        : in  std_logic;
  --! Synchronous reset
  rst        : in  std_logic;
  --! Request or Acknowledge according to selected mode
  req_ack    : in  std_logic := '1';
  --! WGN output with mean=0. Width depends on the generic RESOLUTION.
  dout       : out signed;
  --! Shift register output valid
  dout_vld   : out std_logic;
  --! First output value after loading
  dout_first : out std_logic;
  --! Number of pipeline stages, constant
  PIPESTAGES : out natural := 1
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of noise_normal is

  constant OUTPUT_REG : boolean := false;

  -- Gauss-CDF sample resolution, 2**BITS_GAUSS = overall number of PDF bins
  constant BITS_GAUSS : positive := 4;

  -- Number of Gauss-PDF sample points, e.g. 2^10=1024
  constant D : positive := 10;

  -- Number of adder stages. Per adder stage
  -- * -3.01dB average power (relative to 0dBfs)
  -- *  3.01dB higher Peak to Average Power Ratio (PAPR)
  constant ADDER_STAGES : positive := 2;

  -- Number of LSBs with uniform distribution
  constant BITS_UNIFORM : natural := RESOLUTION - ADDER_STAGES - BITS_GAUSS;

  -- Overall number bit random bits required from LFSR, including additional dither bits.
  -- Minimum width of each single LFSR shall be at least 40 to ensure a long cycle before the sequence repeats.
  -- Combine always LFSRs of different length to 
  -- * avoid correlation
  -- * even extend the cycle of the combined overall LFSR
  constant LFSR_WIDTH : positive := 2**ADDER_STAGES * (D+BITS_UNIFORM) + ADDER_STAGES;
  
  -- Length of first LFSR.
  -- In case of even overall LFSR width ensure that both LFSRs have different length!
  constant LFSR1_WIDTH : positive := (LFSR_WIDTH-1)/2;

  -- Length of second LFSR. Must have different length than first LFSR!
  constant LFSR2_WIDTH : positive := LFSR_WIDTH-LFSR1_WIDTH;

  -- Polynomial of first LFSR
  constant LFSR1_TAPS : integer_vector := MAXIMUM_LENGTH_POLY_4(LFSR1_WIDTH);

  -- Polynomial of second LFSR
  constant LFSR2_TAPS : integer_vector := MAXIMUM_LENGTH_POLY_4(LFSR2_WIDTH);

  -- LFSR seed
  function LFSR_SEED(l:positive) return std_logic_vector is
    variable s : std_logic_vector(l-1 downto 0);
  begin s:=(others=>'0'); s(INSTANCE_IDX):='1'; return s; end function;

  signal lfsr_req_ack : std_logic;
  signal lfsr_dout : std_logic_vector(LFSR1_WIDTH+LFSR2_WIDTH-1 downto 0);
  signal lfsr_dout_vld, lfsr_dout_first : std_logic;

  -- Sampled Gauss-CDF, length=number of bins, because of symmetry only the left half.
  -- Values must be unique and in range 1 to 2**(D-1), last value must be 2**(D-1)
  constant GAUSS_CDF : integer_vector(2**(BITS_GAUSS-1)-1 downto 0) := (7,18,40,81,148,246,371,512); -- -8.98 dBfs
--  constant GAUSS_CDF : integer_vector(2**(BITS_GAUSS-1)-1 downto 0) := (7,17,39,79,147,244,370,512); -- -9.03 dBfs ??

  constant NUM_SUMMAND : positive := 2**ADDER_STAGES;
  constant SUMMAND_WIDTH : positive := BITS_GAUSS+BITS_UNIFORM;

  function get_gauss_level(xin:std_logic_vector) return std_logic_vector is
    variable xlsb : std_logic_vector(xin'length-2 downto 0);
    variable rabs : unsigned(BITS_GAUSS-2 downto 0);
    variable res : std_logic_vector(BITS_GAUSS-1 downto 0);
    alias rsign is res(res'high);
    alias rlsb is res(res'high-1 downto res'low);
  begin
    xlsb := xin(xin'high-1 downto xin'low);
    rsign := xin(xin'high);
    rabs := (others=>'0');
    for n in 1 to (2**(BITS_GAUSS-1)-1) loop
      if unsigned(xlsb)<GAUSS_CDF(n) then rabs:=to_unsigned(n,BITS_GAUSS-1); end if;
    end loop;
    if rsign='1' then
      rlsb := not std_logic_vector(rabs);
    else
      rlsb := std_logic_vector(rabs);
    end if;
    return res;
  end function;

  type t_slv_summand is array(0 to NUM_SUMMAND-1) of std_logic_vector(SUMMAND_WIDTH-1 downto 0);
  signal slv_summand : t_slv_summand;

  signal summand1, summand2 : signed(RESOLUTION-1 downto 0);
  signal summand_vld, summand_first : std_logic;
  
  -- Dither LSBs for all adders
  signal dither : signed(RESOLUTION-1 downto 0) := (others=>'0');

  signal dout_i : signed(RESOLUTION-1 downto 0);
  signal dout_vld_i : std_logic;

begin

  i_lfsr1 : entity siglib.lfsr
  generic map(
    TAPS             => LFSR1_TAPS,
    FIBONACCI        => false,
    SHIFTS_PER_CYCLE => LFSR1_WIDTH + INSTANCE_IDX/2,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => open, -- unused
    OFFSET_LOGIC     => open, -- unused
    TRANSFORM_SEED   => open, -- unused
    OUTPUT_WIDTH     => LFSR1_WIDTH,
    OUTPUT_REG       => OUTPUT_REG
  )
  port map (
    clk        => clk,
    load       => rst,
    seed       => LFSR_SEED(LFSR1_WIDTH),
    req_ack    => lfsr_req_ack,
    dout       => lfsr_dout(LFSR1_WIDTH-1 downto 0),
    dout_vld   => lfsr_dout_vld,
    dout_first => lfsr_dout_first
  );

  i_lfsr2 : entity siglib.lfsr
  generic map(
    TAPS             => LFSR2_TAPS,
    FIBONACCI        => false,
    SHIFTS_PER_CYCLE => LFSR2_WIDTH + INSTANCE_IDX/2,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => open, -- unused
    OFFSET_LOGIC     => open, -- unused
    TRANSFORM_SEED   => open, -- unused
    OUTPUT_WIDTH     => LFSR2_WIDTH,
    OUTPUT_REG       => OUTPUT_REG
  )
  port map (
    clk        => clk,
    load       => rst,
    seed       => LFSR_SEED(LFSR2_WIDTH),
    req_ack    => lfsr_req_ack,
    dout       => lfsr_dout(LFSR1_WIDTH+LFSR2_WIDTH-1 downto LFSR1_WIDTH),
    dout_vld   => open,
    dout_first => open
  );

  g1 : for i in 0 to NUM_SUMMAND-1 generate
    constant OFFSET : integer := i * (D+BITS_UNIFORM);
    alias uniform is lfsr_dout(OFFSET+BITS_UNIFORM-1 downto OFFSET);
    alias gauss is lfsr_dout(OFFSET+D+BITS_UNIFORM-1 downto OFFSET+BITS_UNIFORM);
    signal gauss_level : std_logic_vector(BITS_GAUSS-1 downto 0);
    signal gauss_level_q : std_logic_vector(BITS_GAUSS-1 downto 0);
  begin
    gauss_level <= get_gauss_level(gauss);
--    pipereg(gauss_level_q,gauss_level,clk,clkena);
    gauss_level_q <= gauss_level;
    slv_summand(i)(BITS_UNIFORM-1 downto 0) <= uniform;
    slv_summand(i)(SUMMAND_WIDTH-1 downto BITS_UNIFORM) <= gauss_level_q;
  end generate;

  -- Adder stages
  p_adder : process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        summand1 <= (others=>'-');
        summand2 <= (others=>'-');
        summand_vld <= '0';
        summand_first <= '0';
        dout_i <= (others=>'-');
        dout_vld_i <= '0';
        dout_first <= '0';
      elsif ACKNOWLEDGE_MODE=false or lfsr_req_ack='1' then
        -- first adder stage
        summand1 <= resize(signed(slv_summand(0)),RESOLUTION) + resize(signed(slv_summand(1)),RESOLUTION);
        summand2 <= resize(signed(slv_summand(2)),RESOLUTION) + resize(signed(slv_summand(3)),RESOLUTION);
        summand_vld <= lfsr_dout_vld;
        summand_first <= lfsr_dout_first;
        for n in 0 to ADDER_STAGES-1 loop
          dither(n) <= lfsr_dout(lfsr_dout'high-n);
        end loop;
        -- second adder stage
        dout_i <= resize(summand1,dout_i'length) + resize(summand2,dout_i'length) + resize(dither,dout_i'length);
        dout_vld_i <= summand_vld;
        dout_first <= summand_first;
      end if;
    end if;
  end process;

  -- TODO A : add final dither LSB to avoid DC offset of -1/2 bit.
  -- TODO B : is saturation with final dither LSB addition really required?

  g_req_ack : if ACKNOWLEDGE_MODE generate
    lfsr_req_ack <= (req_ack or (not dout_vld_i)) and (not rst);
  else generate
    lfsr_req_ack <= req_ack;
  end generate;

  dout <= dout_i;
  dout_vld <= dout_vld_i;

  g_pipe : if OUTPUT_REG generate
    PIPESTAGES <= 4;
  else generate
    PIPESTAGES <= 3;
  end generate;

end architecture;
