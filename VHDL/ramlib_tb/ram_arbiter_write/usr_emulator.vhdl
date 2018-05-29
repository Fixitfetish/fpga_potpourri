library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

entity usr_emulator is
generic(
  ADDR_WIDTH : positive; 
  DATA_WIDTH : positive; 
  ADDR_FIRST : unsigned; 
  ADDR_LAST : unsigned; 
  SINGLE_SHOT : std_logic;
  INSTANCE_IDX : natural := 0 
);
port(
  clk             : in  std_logic;
  rst             : in  std_logic;
  vld_pattern     : in  std_logic_vector;
  usr_out_wr_port : buffer r_ram_arbiter_usr_out_wr_port;
  usr_in_wr_port  : in  r_ram_arbiter_usr_in_wr_port
);
end entity;

architecture sim of usr_emulator is

  signal cnt : integer;

  -- use 4 MSBs for instance/channel index and the remaining LSBs for the counter
  signal data_cnt : unsigned(DATA_WIDTH-5 downto 0);
  alias din_idx is usr_out_wr_port.data(DATA_WIDTH-1 downto DATA_WIDTH-4);
  alias din_cnt is usr_out_wr_port.data(DATA_WIDTH-5 downto 0);

  -- GTKWAVE work-around
  signal usr_tx_addr_first : unsigned(ADDR_WIDTH-1 downto 0);
  signal usr_tx_addr_last : unsigned(ADDR_WIDTH-1 downto 0);
  signal usr_tx_single_shot : std_logic;
  signal usr_tx_frame : std_logic;
  signal usr_tx_data : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal usr_tx_data_vld : std_logic;
  signal usr_rx_active : std_logic;
  signal usr_rx_wrap : std_logic;
  signal usr_rx_tx_ovfl : std_logic;
  signal usr_rx_fifo_ovfl : std_logic;
  signal usr_rx_addr_next : unsigned(ADDR_WIDTH-1 downto 0);

begin

  -- GTKWAVE work-around
  usr_tx_addr_first <= usr_out_wr_port.cfg_addr_first;
  usr_tx_addr_last <= usr_out_wr_port.cfg_addr_last;
  usr_tx_single_shot <= usr_out_wr_port.cfg_single_shot;
  usr_tx_frame <= usr_out_wr_port.frame;
  usr_tx_data <= usr_out_wr_port.data;
  usr_tx_data_vld <= usr_out_wr_port.data_vld;
  usr_rx_active <= usr_in_wr_port.active;
  usr_rx_wrap <= usr_in_wr_port.wrap;
  usr_rx_tx_ovfl <= usr_in_wr_port.tx_ovfl;
  usr_rx_fifo_ovfl <= usr_in_wr_port.fifo_ovfl;
  usr_rx_addr_next <= usr_in_wr_port.addr_next;

  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        usr_out_wr_port <= RESET(usr_out_wr_port);
        cnt <= 0;
        data_cnt <= (others=>'0');
      else
        -- control
        usr_out_wr_port.cfg_addr_first <= ADDR_FIRST;
        usr_out_wr_port.cfg_addr_last <= ADDR_LAST;
        usr_out_wr_port.cfg_single_shot <= SINGLE_SHOT;
        usr_out_wr_port.frame <= '1';
        usr_out_wr_port.data_vld <= vld_pattern(cnt);
        if cnt=(vld_pattern'length-1) then
          cnt <= 0;
        else
          cnt <= cnt + 1;  
        end if; 
        -- data
        din_idx <= std_logic_vector(to_unsigned(INSTANCE_IDX,4));
        din_cnt <= std_logic_vector(data_cnt);
        if vld_pattern(cnt)='1' then
          data_cnt <= data_cnt + 1;
        end if;
        
      end if;
    end if;
  end process;


end architecture;
