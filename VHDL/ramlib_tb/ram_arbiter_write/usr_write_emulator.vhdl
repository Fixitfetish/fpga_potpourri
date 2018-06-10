library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

entity usr_write_emulator is
generic(
  ARBITER_ADDR_WIDTH : positive; 
  ARBITER_DATA_WIDTH : positive; 
  USER_DATA_WIDTH : positive; 
  ADDR_FIRST : unsigned; 
  ADDR_LAST : unsigned; 
  SINGLE_SHOT : std_logic;
  INSTANCE_IDX : natural := 0 
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

architecture sim of usr_write_emulator is

  -- use 4 MSBs for instance/channel index and the remaining LSBs for the counter
  signal data_cnt : unsigned(USER_DATA_WIDTH-5 downto 0);

  signal usr_req_data : std_logic_vector(USER_DATA_WIDTH-1 downto 0);
  alias usr_req_data_id  is usr_req_data(USER_DATA_WIDTH-1 downto USER_DATA_WIDTH-4);
  alias usr_req_data_cnt is usr_req_data(USER_DATA_WIDTH-5 downto 0);

begin

  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' or usr_req_frame='0' then
        data_cnt <= (others=>'0');
      elsif usr_req_ena='1' then
        data_cnt <= data_cnt + 1;
      end if;
    end if;
  end process;


  usr_req_data_id <= std_logic_vector(to_unsigned(INSTANCE_IDX,4));
  usr_req_data_cnt <= std_logic_vector(data_cnt);


  i_adapt : entity ramlib.ram_arbiter_write_data_width_adapter
  generic map(
    RAM_ARBITER_DATA_WIDTH => ARBITER_DATA_WIDTH,
    RAM_ARBITER_ADDR_WIDTH => ARBITER_ADDR_WIDTH,
    USER_DATA_WIDTH => USER_DATA_WIDTH
  )
  port map(
    clk                 => clk,
    rst                 => rst,
    usr_cfg_addr_first  => ADDR_FIRST,
    usr_cfg_addr_last   => ADDR_LAST,
    usr_cfg_single_shot => SINGLE_SHOT,
    usr_req_frame       => usr_req_frame,
    usr_req_ena         => usr_req_ena,
    usr_req_data        => usr_req_data,
    usr_req_ovfl        => open,
    usr_req_fifo_ovfl   => open,
    arb_out             => arb_out,
    arb_in              => arb_in
  );


end architecture;
