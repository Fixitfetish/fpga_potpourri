library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

entity usr_adapter_emulator is
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
  clk             : in  std_logic;
  rst             : in  std_logic;
  frame           : in  std_logic;
  vld_pattern     : in  std_logic_vector;
  usr_out_wr_port : out r_ram_arbiter_usr_out_wr_port;
  usr_in_wr_port  : in  r_ram_arbiter_usr_in_wr_port
);
end entity;

-------------------------------------------------------------------------------

architecture sim of usr_adapter_emulator is

  signal cnt : integer;

  -- use 4 MSBs for instance/channel index and the remaining LSBs for the counter
  signal data_cnt : unsigned(USER_DATA_WIDTH-5 downto 0);
  signal adapt_usr_out_wr_port : r_ram_arbiter_usr_out_wr_port(
                     cfg_addr_first(ARBITER_ADDR_WIDTH-1 downto 0),
                     cfg_addr_last(ARBITER_ADDR_WIDTH-1 downto 0),
                     data(USER_DATA_WIDTH-1 downto 0) );
  signal adapt_usr_in_wr_port : r_ram_arbiter_usr_in_wr_port(
                     addr_next(ARBITER_ADDR_WIDTH-1 downto 0) );

  alias din_idx is adapt_usr_out_wr_port.data(USER_DATA_WIDTH-1 downto USER_DATA_WIDTH-4);
  alias din_cnt is adapt_usr_out_wr_port.data(USER_DATA_WIDTH-5 downto 0);


begin

  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        adapt_usr_out_wr_port <= RESET(adapt_usr_out_wr_port);
        cnt <= 0;
        data_cnt <= (others=>'0');
      else
        -- control
        adapt_usr_out_wr_port.cfg_addr_first <= ADDR_FIRST;
        adapt_usr_out_wr_port.cfg_addr_last <= ADDR_LAST;
        adapt_usr_out_wr_port.cfg_single_shot <= SINGLE_SHOT;
        adapt_usr_out_wr_port.frame <= frame;
        adapt_usr_out_wr_port.data_vld <= vld_pattern(cnt);
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


  i_adapt : entity ramlib.ram_arbiter_write_data_width_adapter
  generic map(
    RAM_ARBITER_DATA_WIDTH => ARBITER_DATA_WIDTH,
    RAM_ARBITER_ADDR_WIDTH => ARBITER_ADDR_WIDTH,
    USER_DATA_WIDTH => USER_DATA_WIDTH
  )
  port map(
    clk                 => clk,
    rst                 => rst,
    arb_usr_out_wr_port => usr_out_wr_port,
    arb_usr_in_wr_port  => usr_in_wr_port,
    usr_out_wr_port     => adapt_usr_out_wr_port,
    usr_in_wr_port      => adapt_usr_in_wr_port
  );


end architecture;

