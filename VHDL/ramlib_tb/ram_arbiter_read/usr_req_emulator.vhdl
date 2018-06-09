library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

entity usr_req_emulator is
generic(
  DATA_WIDTH : positive; 
  INSTANCE_IDX : natural := 0 
);
port(
  clk             : in  std_logic;
  rst             : in  std_logic;
  vld_pattern     : in  std_logic_vector;
  din             : out std_logic_vector(DATA_WIDTH-1 downto 0);
  din_vld         : out std_logic;
  din_frame       : out std_logic := '0'
);
end entity;

architecture sim of usr_req_emulator is

  signal cnt : integer;

  -- use 4 MSBs for instance/channel index and the remaining LSBs for the counter
  signal data_cnt : unsigned(DATA_WIDTH-5 downto 0);
  alias din_idx is din(DATA_WIDTH-1 downto DATA_WIDTH-4);
  alias din_cnt is din(DATA_WIDTH-5 downto 0);

begin

  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        din <= (others=>'-');
        din_frame <= '0';
        din_vld <= '0';
        cnt <= 0;
        data_cnt <= (others=>'0');
      else
        -- control
        din_frame <= '1';
        din_vld <= vld_pattern(cnt);
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

