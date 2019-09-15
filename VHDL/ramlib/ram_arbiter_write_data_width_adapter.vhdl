-------------------------------------------------------------------------------
--! @file       ram_arbiter_write_data_width_adapter.vhdl
--! @author     Fixitfetish
--! @date       25/Jul/2018
--! @version    0.20
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

--! @brief Entity that adapts user data width to the arbiter data width using a shift register.
--!
--! The user can request data of width RAM_ARBITER_DATA_WIDTH/(2**RATIO_LOG2) every cycle.
--! Always N = 2**RATIO_LOG2 requests are collected before an arbiter request is generated.
--! Hence, the resulting minimum arbiter request period is N cycles.
--!
entity ram_arbiter_write_data_width_adapter is
generic(
  --! RAM Data Width must be a multiple of 2**USER_MAX_RATIO_LOG2
  RAM_ARBITER_DATA_WIDTH : positive;
  --! RAM Address Width (RAM arbiter data word address)
  RAM_ARBITER_ADDR_WIDTH : positive;
  --! @brief Minimum RAM-to-USER data width ratio. LOG2 enforces ratio with power of 2.
  --! To not waste FPGA logic choose as large as possible but <=USER_MAX_RATIO_LOG2.
  USER_MIN_RATIO_LOG2 : natural := 0;
  --! @brief Maximum RAM-to-USER data width ratio. LOG2 enforces ratio with power of 2.
  --! To not waste FPGA logic choose as small as possible but >=USER_MIN_RATIO_LOG2.
  USER_MAX_RATIO_LOG2 : natural := 4
);
port(
  --! System clock
  clk                 : in  std_logic;
  --! Synchronous reset
  rst                 : in  std_logic;
  --! start address (must be valid at rising edge of frame signal)
  usr_cfg_addr_first  : in  unsigned(RAM_ARBITER_ADDR_WIDTH-1 downto 0); 
  --! last address before wrap (must be valid at rising edge of frame signal)
  usr_cfg_addr_last   : in  unsigned(RAM_ARBITER_ADDR_WIDTH-1 downto 0); 
  --! '1'=single-shot mode , '0'=continuous with wrap (must be valid at rising edge of frame signal)
  usr_cfg_single_shot : in  std_logic;
  --! @brief Number of user requests (log2) per RAM request.
  --! Must be in range USER_MIN_RATIO_LOG2 to USER_MAX_RATIO_LOG2. 
  --! Do not change while frame is active.
  --! The resulting USER_DATA_WIDTH is RAM_ARBITER_DATA_WIDTH/(2**usr_cfg_ratio_log2) .
  --! Example: For RAM_ARBITER_DATA_WIDTH=512 and ratio_log2=3 results in USER_DATA_WIDTH=64.  
  usr_cfg_ratio_log2  : in  unsigned;
  --! request frame, start=rising edge, stop=falling edge 
  usr_req_frame       : in  std_logic;
  --! request enable
  usr_req_ena         : in  std_logic;
  --! request data (write)
  usr_req_data        : in  std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0); 
  --! request overflow reported by arbiter
  usr_req_ovfl        : out std_logic;
  --! request FIFO overflow reported by arbiter
  usr_req_fifo_ovfl   : out std_logic;
  --! channel active
  usr_status_active   : out std_logic;
  --! wrap after last request address occurred (disabled single-shot only)
  usr_status_wrap     : out std_logic;
  --! next request address (hold after frame end)
  usr_status_addr_next: out unsigned(RAM_ARBITER_ADDR_WIDTH-1 downto 0); 
  --! Arbiter output signals (from arbiter to user)
  arb_out             : in  r_ram_arbiter_usr_in_port;
  --! Arbiter input signals (from user to arbiter)
  arb_in              : out r_ram_arbiter_usr_out_port
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of ram_arbiter_write_data_width_adapter is

  signal arb_in_req_frame : std_logic;
  signal arb_in_req_ena : std_logic;

begin

  -- debug
  arb_in_req_frame <= arb_in.req_frame;
  arb_in_req_ena <= arb_in.req_ena;

  -- request generation
  p_cfg : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        arb_in.cfg_addr_first <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_addr_last <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_single_shot <= '0';
      else
        arb_in.cfg_addr_first <= usr_cfg_addr_first;
        arb_in.cfg_addr_last <= usr_cfg_addr_last;
        arb_in.cfg_single_shot <= usr_cfg_single_shot;        
      end if; --reset 
    end if; --clock
  end process;

  i_pack : entity baselib.slv_pack
  generic map(
    DATA_WIDTH        => RAM_ARBITER_DATA_WIDTH,
    MIN_RATIO_LOG2    => USER_MIN_RATIO_LOG2,
    MAX_RATIO_LOG2    => USER_MAX_RATIO_LOG2,
    MSB_BOUND_INPUT   => false,
    MSB_BOUND_OUTPUT  => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    ratio_log2 => usr_cfg_ratio_log2,
    din_frame  => usr_req_frame,
    din_ena    => usr_req_ena,
    din        => usr_req_data,
    dout_frame => arb_in.req_frame,
    dout_ena   => arb_in.req_ena,
    dout       => arb_in.req_data
  );


  -- status reporting (with pipeline register)
  usr_status_active <= arb_out.active when rising_edge(clk);
  usr_status_wrap <= arb_out.wrap when rising_edge(clk);
  usr_status_addr_next <= arb_out.addr_next when rising_edge(clk);

  -- error reporting (with pipeline register)
  usr_req_ovfl <= arb_out.req_ovfl when rising_edge(clk);
  usr_req_fifo_ovfl <= arb_out.req_fifo_ovfl when rising_edge(clk);

  -- completion acknowledge is irrelevant (only required for read)
  arb_in.cpl_ack <= '0';

end architecture;
