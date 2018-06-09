library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

entity bus_cpl_emulator is
generic(
  DATA_WIDTH : positive; 
  CPL_DELAY : positive range 2 to integer'high 
);
port(
  clk           : in  std_logic;
  rst           : in  std_logic;
  req_ena       : in  std_logic;
  req_usr_id    : in  unsigned;
  cpl_data      : out std_logic_vector(DATA_WIDTH-1 downto 0);
  cpl_data_vld  : out std_logic
);
end entity;

architecture sim of bus_cpl_emulator is

  type r_req is
  record
    ena    : std_logic;
    usr_id : unsigned(req_usr_id'length-1 downto 0);
  end record;
  type a_req is array(integer range <>) of r_req;
  signal req_q : a_req(1 to CPL_DELAY) := (others=>('0',(others=>'-')));

  -- use 4 MSBs for port index and the remaining LSBs for the counter
  type a_port_cnt is array(integer range <>) of unsigned(DATA_WIDTH-5 downto 0);
  signal port_cnt : a_port_cnt(0 to 2**req_usr_id'length-1);

  alias cpl_data_idx is cpl_data(DATA_WIDTH-1 downto DATA_WIDTH-4);
  alias cpl_data_cnt is cpl_data(DATA_WIDTH-5 downto 0);

begin

  p_delay : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        req_q <= (others=>('0',(others=>'-')));
      else
        req_q(1).ena <= req_ena;
        req_q(1).usr_id <= req_usr_id;
        for n in 2 to CPL_DELAY loop
          req_q(n) <= req_q(n-1);
        end loop;
      end if;
    end if;
  end process;

  p_cnt : process(clk)
    variable v_idx : unsigned(cpl_data_idx'length-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst='1' then
        cpl_data <= (others=>'-');
        cpl_data_vld <= '0';
        port_cnt <= (others=>(others=>'0'));
      else
        v_idx := resize(req_q(CPL_DELAY).usr_id,v_idx'length);
        if req_q(CPL_DELAY).ena='1' then
          cpl_data_idx <= std_logic_vector(v_idx);
          cpl_data_cnt <= std_logic_vector(port_cnt(to_integer(v_idx)));
          port_cnt(to_integer(v_idx)) <= port_cnt(to_integer(v_idx)) + 1;
        end if; 
        cpl_data_vld <= req_q(CPL_DELAY).ena;
      end if;
    end if;
  end process;

end architecture;
