-------------------------------------------------------------------------------
--! @file       ram_arbiter_read_data_width_adapter.vhdl
--! @author     Fixitfetish
--! @date       12/Aug/2018
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
--! Corresponding to the arbiter request period the arbiter read completions are auto-acknowledged
--! with a minimum period of N cycles. Hence, the extracted read data for the user can be provided every cycle. 

entity ram_arbiter_read_data_width_adapter is
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
  --! request overflow reported by arbiter
  usr_req_ovfl        : out std_logic;
  --! request FIFO overflow reported by arbiter
  usr_req_fifo_ovfl   : out std_logic;
  --! read completion data
  usr_cpl_data        : out std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  --! read completion data valid
  usr_cpl_data_vld    : out std_logic;
  --! read completion data end of frame
  usr_cpl_data_eof    : out std_logic;
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
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert USER_MIN_RATIO_LOG2<=USER_MAX_RATIO_LOG2
    report "ERROR in " & ram_arbiter_read_data_width_adapter'INSTANCE_NAME & 
           " Minimum RATIO_LOG2 must be smaller or equal the maximum RATIO_LOG2."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of ram_arbiter_read_data_width_adapter is

  signal cfg_ratio_log2 : unsigned(usr_cfg_ratio_log2'range);
  signal cfg_ratio : unsigned(USER_MAX_RATIO_LOG2 downto 0);
  signal usr_req_frame_q : std_logic;

  signal cpl_ack : std_logic;
  
  signal arb_out_cpl_frame_q : std_logic;
  signal arb_out_cpl_data_q : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  signal arb_out_cpl_data_vld_q : std_logic;
  signal arb_out_cpl_data_eof_q : std_logic;

  signal arb_out_cpl_frame : std_logic;

  type t_din is
  record
    frame : std_logic;
    rdy   : std_logic;
    ena   : std_logic;
    eof   : std_logic;
    data  : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
    ovfl  : std_logic;
  end record;
  signal din : t_din;

  -- debug
  signal arb_in_req_frame : std_logic;
  signal arb_in_req_ena : std_logic;
  signal arb_in_cpl_ack : std_logic;
  signal arb_out_cpl_rdy : std_logic;
  signal arb_out_cpl_ack_ovfl : std_logic;
  signal arb_out_cpl_fifo_ovfl : std_logic;
  signal arb_out_cpl_data_vld : std_logic;
  signal arb_out_cpl_data_eof : std_logic;
  signal arb_out_cpl_data : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  signal din_frame : std_logic;  
  signal din_rdy : std_logic;  
  signal din_ena : std_logic;  
  signal din_eof : std_logic;  
  signal din_data : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  signal din_ovfl : std_logic;  

begin

  -- debug
  arb_in_req_frame <= arb_in.req_frame;
  arb_in_req_ena <= arb_in.req_ena;
  arb_in_cpl_ack <= arb_in.cpl_ack;
  arb_out_cpl_rdy <= arb_out.cpl_rdy;
  arb_out_cpl_ack_ovfl <= arb_out.cpl_ack_ovfl;
  arb_out_cpl_fifo_ovfl <= arb_out.cpl_fifo_ovfl;
  arb_out_cpl_data_vld <= arb_out.cpl_data_vld;
  arb_out_cpl_data_eof <= arb_out.cpl_data_eof;
  arb_out_cpl_data <= arb_out.cpl_data;
  din_frame <= din.frame;
  din_rdy <= din.rdy;
  din_ena <= din.ena;
  din_eof <= din.eof;
  din_data <= din.data;
  din_ovfl <= din.ovfl;

  -- request generation
  p_req : process(clk)
    variable v_cnt : unsigned(cfg_ratio'range);
  begin
    if rising_edge(clk) then
      arb_in.req_ena <= '0'; -- default
      usr_req_frame_q <= usr_req_frame; -- for edge detection
      
      cfg_ratio_log2 <= usr_cfg_ratio_log2;
      cfg_ratio <= SHIFT_LEFT(to_unsigned(1,cfg_ratio'length),to_integer(usr_cfg_ratio_log2));

      if rst='1' or usr_req_frame='0' then
        arb_in.cfg_addr_first <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_addr_last <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_single_shot <= '0';
        arb_in.req_frame <= '0';
        v_cnt := to_unsigned(1,v_cnt'length);

      else
        if usr_req_frame_q='0' then
          -- hold parameters with rising edge of frame
          arb_in.cfg_addr_first <= usr_cfg_addr_first;
          arb_in.cfg_addr_last <= usr_cfg_addr_last;
          arb_in.cfg_single_shot <= usr_cfg_single_shot;
          arb_in.req_frame <= '1';
        end if;
        
        if usr_req_ena='1' then
          if v_cnt=1 then
            arb_in.req_ena <= '1';
            v_cnt := cfg_ratio;
          else
            v_cnt := v_cnt - 1;
          end if;
        end if;

      end if; --reset 

      -- request data is irrelevant (only required for write)
      arb_in.req_data <= (RAM_ARBITER_DATA_WIDTH-1 downto 0 => '-');

    end if; --clock
  end process;


  -- status reporting (with pipeline register)
  usr_status_active <= arb_out.active when rising_edge(clk);
  usr_status_wrap <= arb_out.wrap when rising_edge(clk);
  usr_status_addr_next <= arb_out.addr_next when rising_edge(clk);

  -- error reporting (with pipeline register)
  usr_req_ovfl <= arb_out.req_ovfl when rising_edge(clk);
  usr_req_fifo_ovfl <= arb_out.req_fifo_ovfl when rising_edge(clk);

  -- completion acknowledge
  arb_in.cpl_ack <= arb_out.cpl_rdy and cpl_ack;  

  -- completion acknowledge rate according to RAM request rate
  -- (i.e. according to data width conversion factor)
  p_cpl_ack : process(clk)
    variable v_cnt : unsigned(cfg_ratio'range);
  begin
    if rising_edge(clk) then
      cpl_ack <= '0'; -- default
      if rst='1' then
        v_cnt := cfg_ratio;
      else
        if arb_out.cpl_rdy='1' and v_cnt=cfg_ratio then
          cpl_ack <= '1';
          v_cnt := to_unsigned(1,v_cnt'length);
        elsif v_cnt/=cfg_ratio then
          v_cnt := v_cnt + 1;
        end if;
      end if;

    end if;
  end process;

  p_arb_out_cpl_frame : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' or arb_out.cpl_data_eof='1'then
        arb_out_cpl_frame <= '0';
      elsif arb_out.active='1' then
        arb_out_cpl_frame <= '1';
      end if;
    end if;
  end process;

  -- completion data buffer is needed as
  -- + user specific pipeline register after the common CPL FIFO output register
  -- + additional one-stage FIFO to compensate cpl_ack delays 
  p_cpl_buffer : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        arb_out_cpl_frame_q <= '0';
        arb_out_cpl_data_q <= (others=>'-');
        arb_out_cpl_data_vld_q <= '0';
        arb_out_cpl_data_eof_q <= '0';
      else
        -- hold data until acknowledged
        if arb_out.cpl_data_vld='1' then
          arb_out_cpl_data_q <= arb_out.cpl_data;
        end if;
        arb_out_cpl_frame_q <= arb_out_cpl_frame or (arb_out_cpl_frame_q and (not din.rdy));
        arb_out_cpl_data_vld_q <= arb_out.cpl_data_vld or (arb_out_cpl_data_vld_q and (not din.rdy));
        arb_out_cpl_data_eof_q <= arb_out.cpl_data_eof or (arb_out_cpl_data_eof_q and (not din.rdy));
      end if;
    end if;
  end process;

  din.frame <= arb_out_cpl_frame_q;
  din.ena <= arb_out_cpl_data_vld_q and din.rdy;
  din.eof <= arb_out_cpl_data_eof_q;
  din.data <= arb_out_cpl_data_q;

  i_unpack : entity baselib.slv_unpack
  generic map(
    DATA_WIDTH        => RAM_ARBITER_DATA_WIDTH,
    MIN_RATIO_LOG2    => USER_MIN_RATIO_LOG2,
    MAX_RATIO_LOG2    => USER_MAX_RATIO_LOG2,
    MSB_BOUND_INPUT   => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    ratio_log2 => usr_cfg_ratio_log2,
    din_frame  => din.frame,
    din_ena    => din.ena,
    din_eof    => din.eof,
    din        => din.data,
    din_rdy    => din.rdy,
    din_ovfl   => din.ovfl, -- TODO
    dout_frame => open, -- unused,
    dout_ena   => usr_cpl_data_vld,
    dout_eof   => usr_cpl_data_eof,
    dout       => usr_cpl_data
  );

end architecture;
