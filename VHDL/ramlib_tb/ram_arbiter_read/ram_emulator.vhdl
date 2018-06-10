library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

-- return data is the trimmed read address

entity ram_emulator is
generic(
  ADDR_WIDTH : positive; 
  DATA_WIDTH : positive; 
  READ_DELAY : positive range 2 to integer'high 
);
port(
  clk              : in  std_logic;
  rst              : in  std_logic;
  --! read/write address
  ram_in_addr      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
  --! address valid
  ram_in_addr_vld  : in  std_logic;
  --! ready to accept read/write requests, default is '1'
  ram_out_rdy      : out std_logic := '1';
  --! RAM read data
  ram_out_data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
  --! RAM read data valid
  ram_out_data_vld : out std_logic
);
end entity;

architecture sim of ram_emulator is

  type r_ram_in is
  record
    vld  : std_logic;
    addr : unsigned(ADDR_WIDTH-1 downto 0);
  end record;
  type a_ram_in is array(integer range <>) of r_ram_in;
  signal ram_in_q : a_ram_in(1 to READ_DELAY) := (others=>('0',(others=>'-')));

begin

  p_delay : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        ram_in_q <= (others=>('0',(others=>'-')));
      else
        ram_in_q(1).vld <= ram_in_addr_vld;
        if ram_in_addr_vld='1' then
          ram_in_q(1).addr <= unsigned(ram_in_addr);
        end if;
        for n in 2 to READ_DELAY loop
          ram_in_q(n) <= ram_in_q(n-1);
        end loop;
      end if;
    end if;
  end process;

  ram_out_data <= std_logic_vector(resize(ram_in_q(READ_DELAY).addr,DATA_WIDTH));
  ram_out_data_vld <= ram_in_q(READ_DELAY).vld;
  
end architecture;
