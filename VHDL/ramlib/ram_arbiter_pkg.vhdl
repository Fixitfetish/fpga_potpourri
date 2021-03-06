-------------------------------------------------------------------------------
--! @file       ram_arbiter_pkg.vhdl
--! @author     Fixitfetish
--! @date       10/Jun/2018
--! @version    0.60
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package ram_arbiter_pkg is

  --! Data word address width 
  constant RAM_ADDR_WIDTH : positive := 16;

  --! data width in bits
  constant RAM_DATA_WIDTH : positive := 32;

  --! User output port, control and read/write request
  type r_ram_arbiter_usr_out_port is
  record
    --! start address (must be valid at rising edge of frame signal)
    cfg_addr_first : unsigned(RAM_ADDR_WIDTH-1 downto 0); 
    --! last address before wrap (must be valid at rising edge of frame signal)
    cfg_addr_last : unsigned(RAM_ADDR_WIDTH-1 downto 0); 
    --! '1'=single-shot mode , '0'=continuous with wrap (must be valid at rising edge of frame signal)
    cfg_single_shot : std_logic;
    --! request frame, start=rising edge, stop=falling edge 
    req_frame : std_logic;
    --! request enable
    req_ena : std_logic;
    --! request data (relevant for write only)
    req_data : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
    --! completion acknowledge (relevant for read only)
    cpl_ack : std_logic;
  end record;
  type a_ram_arbiter_usr_out_port is array(integer range <>) of r_ram_arbiter_usr_out_port; 
  function RESET(x:r_ram_arbiter_usr_out_port) return r_ram_arbiter_usr_out_port;
  function RESET(x:a_ram_arbiter_usr_out_port) return a_ram_arbiter_usr_out_port;
--  constant DEFAULT_RAM_ARBITER_USR_OUT_PORT : r_ram_arbiter_usr_out_port := (
--    cfg_addr_first => (others=>'-'),
--    cfg_addr_last => (others=>'-'),
--    cfg_single_shot => '0',
--    req_frame => '0',
--    req_ena => '0',
--    req_data => (others=>'-'),
--    cpl_ack => '0'
--  );

  --! User input port, status and read data
  type r_ram_arbiter_usr_in_port is
  record
    --! channel active
    active : std_logic;
    --! address pointer wrapped at least once (sticky bit)
    wrap : std_logic;
    --! current RAM address pointer (next address)
    addr_next : unsigned(RAM_ADDR_WIDTH-1 downto 0);
    --! request overflow
    req_ovfl : std_logic;
    --! request FIFO overflow
    req_fifo_ovfl : std_logic;
    --! completion data ready/available (relevant for read only)
    cpl_rdy : std_logic;
    --! completion acknowledge overflow (relevant for read only)
    cpl_ack_ovfl : std_logic;
    --! completion FIFO overflow (relevant for read only)
    cpl_fifo_ovfl : std_logic;
    --! completion data valid (relevant for read only)
    cpl_data_vld : std_logic;
    --! completion data end of frame (relevant for read only)
    cpl_data_eof : std_logic;
    --! completion data (relevant for read only)
    cpl_data : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
  end record;
  type a_ram_arbiter_usr_in_port is array(integer range <>) of r_ram_arbiter_usr_in_port; 
  function RESET(x:r_ram_arbiter_usr_in_port) return r_ram_arbiter_usr_in_port;
  function RESET(x:a_ram_arbiter_usr_in_port) return a_ram_arbiter_usr_in_port;
--  constant DEFAULT_RAM_ARBITER_USR_IN_PORT : r_ram_arbiter_usr_in_port := (
--    active => '0',
--    wrap => '0',
--    addr_next => (others=>'0'),
--    req_ovfl => '0',
--    req_fifo_ovfl => '0',
--    cpl_rdy => '0',
--    cpl_ack_ovfl => '0',
--    cpl_fifo_ovfl => '0',
--    cpl_data_vld => '0',
--    cpl_data_eof => '0',
--    cpl_data => (others=>'-')
--  );

end package;

-------------------------------------------------------------------------------

package body ram_arbiter_pkg is

  function RESET(x:r_ram_arbiter_usr_out_port)
  return r_ram_arbiter_usr_out_port is
    variable res : r_ram_arbiter_usr_out_port;
    -- VHDL-2008
--    variable res : x'subtype;
--    variable res : r_ram_arbiter_usr_out_port(
--                     cfg_addr_first(x.cfg_addr_first'range),
--                     cfg_addr_last(x.cfg_addr_last'range),
--                     req_data(x.req_data'range) );
  begin
    res.cfg_addr_first := (others=>'-');
    res.cfg_addr_last := (others=>'-');
--    res.cfg_addr_first := (x.cfg_addr_first'range=>'-');
--    res.cfg_addr_last := (x.cfg_addr_last'range=>'-');
    res.cfg_single_shot := '0';
    res.req_frame := '0';
    res.req_ena := '0';
    res.req_data := (others=>'-');
--    res.req_data := (x.req_data'range=>'-');
    res.cpl_ack := '0';
    return res;
  end function;

  function RESET(x:a_ram_arbiter_usr_out_port)
  return a_ram_arbiter_usr_out_port is
    variable res : a_ram_arbiter_usr_out_port(x'range);
    -- VHDL-2008
--    variable res : x'subtype;
--    variable res : a_ram_arbiter_usr_out_wr_port(x'range)(
--                     cfg_addr_first(x(x'low).cfg_addr_first'range),
--                     cfg_addr_last(x(x'low).cfg_addr_last'range),
--                     req_data(x(x'low).req_data'range) );
  begin
    for i in x'range loop res(i):=RESET(x(i)); end loop;  
    return res;
  end function;


  function RESET(x:r_ram_arbiter_usr_in_port)
  return r_ram_arbiter_usr_in_port is
    variable res : r_ram_arbiter_usr_in_port;
    -- VHDL-2008
--    variable res : x'subtype;
  begin
    res.active := '0';
    res.wrap := '0';
    res.addr_next := (x.addr_next'range=>'0');
    res.req_ovfl := '0';
    res.req_fifo_ovfl := '0';
    res.cpl_rdy := '0';
    res.cpl_ack_ovfl := '0';
    res.cpl_fifo_ovfl := '0';
    res.cpl_data_vld := '0';
    res.cpl_data_eof := '0';
    res.cpl_data := (x.cpl_data'range=>'-');
    return res;
  end function;

  function RESET(x:a_ram_arbiter_usr_in_port)
  return a_ram_arbiter_usr_in_port is
    variable res : a_ram_arbiter_usr_in_port(x'range);
    -- VHDL-2008
--    variable res : x'subtype;
  begin
    for i in x'range loop res(i):=RESET(x(i)); end loop;  
    return res;
  end function;
  
  
end package body;
