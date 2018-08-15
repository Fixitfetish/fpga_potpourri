library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

entity usr_read_emulator is
generic(
  ARBITER_ADDR_WIDTH : positive; 
  ARBITER_DATA_WIDTH : positive; 
  USER_DATA_WIDTH : positive; 
  ADDR_FIRST : unsigned; 
  ADDR_LAST : unsigned; 
  SINGLE_SHOT : std_logic
);
port(
  clk           : in  std_logic;
  rst           : in  std_logic;
  usr_req_frame : in  std_logic;
  usr_req_ena   : in  std_logic;
  arb_out       : in  r_ram_arbiter_usr_in_port;
  arb_in        : out r_ram_arbiter_usr_out_port
);
end entity;

-------------------------------------------------------------------------------

architecture sim of usr_read_emulator is

  constant RATIO : positive := ARBITER_DATA_WIDTH/USER_DATA_WIDTH;
  constant RATIO_LOG2 : natural := log2ceil(RATIO);

  constant cfg_ratio_log2 : unsigned(2 downto 0) := to_unsigned(RATIO_LOG2,3);

  type t_usr_req is
  record
    frame     : std_logic;
    ena       : std_logic;
    ovfl      : std_logic;
    fifo_ovfl : std_logic;
  end record;
  signal usr_req : t_usr_req;

  type t_usr_cpl is
  record
    data_vld  : std_logic;
    data_eof  : std_logic;
    data      : std_logic_vector(ARBITER_DATA_WIDTH-1 downto 0);
  end record;
  signal usr_cpl : t_usr_cpl;

  type t_usr_status is
  record
    active   : std_logic;
    wrap     : std_logic;
    addr_next: unsigned(ARBITER_ADDR_WIDTH-1 downto 0); 
  end record;
  signal usr_status : t_usr_status;
  
  -- debug
  signal usr_cpl_data_vld  : std_logic;
  signal usr_cpl_data_eof  : std_logic;
  signal usr_cpl_data      : std_logic_vector(ARBITER_DATA_WIDTH-1 downto 0);

begin

  -- debug
  usr_cpl_data <= usr_cpl.data;
  usr_cpl_data_vld <= usr_cpl.data_vld;
  usr_cpl_data_eof <= usr_cpl.data_eof;

  usr_req.frame <= usr_req_frame;
  usr_req.ena <= usr_req_ena;
  
  i_adapt : entity ramlib.ram_arbiter_read_data_width_adapter
  generic map(
    RAM_ARBITER_DATA_WIDTH => ARBITER_DATA_WIDTH,
    RAM_ARBITER_ADDR_WIDTH => ARBITER_ADDR_WIDTH,
    USER_MIN_RATIO_LOG2 => 0,
    USER_MAX_RATIO_LOG2 => 2
  )
  port map(
    clk                 => clk,
    rst                 => rst,
    usr_cfg_addr_first  => ADDR_FIRST,
    usr_cfg_addr_last   => ADDR_LAST,
    usr_cfg_single_shot => SINGLE_SHOT,
    usr_cfg_ratio_log2  => cfg_ratio_log2,
    usr_req_frame       => usr_req.frame,
    usr_req_ena         => usr_req.ena,
    usr_req_ovfl        => usr_req.ovfl,
    usr_req_fifo_ovfl   => usr_req.fifo_ovfl,
    usr_cpl_data        => usr_cpl.data,
    usr_cpl_data_vld    => usr_cpl.data_vld,
    usr_cpl_data_eof    => usr_cpl.data_eof,
    usr_status_active   => usr_status.active,
    usr_status_wrap     => usr_status.wrap,
    usr_status_addr_next=> usr_status.addr_next,
    arb_out             => arb_out,
    arb_in              => arb_in
  );


end architecture;
