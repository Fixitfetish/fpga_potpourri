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
  ADDR_FIRST : unsigned(ramlib.ram_arbiter_pkg.ADDR_WIDTH-1 downto 0); 
  ADDR_LAST : unsigned(ramlib.ram_arbiter_pkg.ADDR_WIDTH-1 downto 0); 
  SINGLE_SHOT : std_logic;
  INSTANCE_IDX : natural := 0 
);
port(
  clk             : in  std_logic;
  rst             : in  std_logic;
  vld_pattern     : in  std_logic_vector;
  usr_wr_port_tx  : buffer r_ram_arbiter_wr_port_tx;
  usr_wr_port_rx  : in  r_ram_arbiter_wr_port_rx
);
end entity;

architecture sim of usr_emulator is

  constant DATA_WIDTH : positive := ramlib.ram_arbiter_pkg.DATA_WIDTH;
  constant ADDR_WIDTH : positive := ramlib.ram_arbiter_pkg.ADDR_WIDTH;
  
  signal cnt : integer;

  -- use 4 MSBs for instance/channel index and the remaining LSBs for the counter
  signal data_cnt : unsigned(DATA_WIDTH-5 downto 0);
  alias din_idx is usr_wr_port_tx.data(DATA_WIDTH-1 downto DATA_WIDTH-4);
  alias din_cnt is usr_wr_port_tx.data(DATA_WIDTH-5 downto 0);

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
  usr_tx_addr_first <= usr_wr_port_tx.cfg_addr_first;
  usr_tx_addr_last <= usr_wr_port_tx.cfg_addr_last;
  usr_tx_single_shot <= usr_wr_port_tx.cfg_single_shot;
  usr_tx_frame <= usr_wr_port_tx.frame;
  usr_tx_data <= usr_wr_port_tx.data;
  usr_tx_data_vld <= usr_wr_port_tx.data_vld;
  usr_rx_active <= usr_wr_port_rx.active;
  usr_rx_wrap <= usr_wr_port_rx.wrap;
  usr_rx_tx_ovfl <= usr_wr_port_rx.tx_ovfl;
  usr_rx_fifo_ovfl <= usr_wr_port_rx.fifo_ovfl;
  usr_rx_addr_next <= usr_wr_port_rx.addr_next;

  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
--        usr_wr_port_tx <= DEFAULT_RAM_ARBITER_WR_PORT_TX;
        usr_wr_port_tx <= RESET(usr_wr_port_tx);
        cnt <= 0;
        data_cnt <= (others=>'0');
      else
        -- control
        usr_wr_port_tx.cfg_addr_first <= ADDR_FIRST;
        usr_wr_port_tx.cfg_addr_last <= ADDR_LAST;
        usr_wr_port_tx.cfg_single_shot <= SINGLE_SHOT;
        usr_wr_port_tx.frame <= '1';
--        usr_wr_port_tx.data <= (DATA_WIDTH-1 downto 0=>'0');
        usr_wr_port_tx.data_vld <= vld_pattern(cnt);
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

