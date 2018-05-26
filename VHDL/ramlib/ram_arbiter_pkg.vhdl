library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package ram_arbiter_pkg is
  
  --! Data word address width 
  constant ADDR_WIDTH : positive := 16;

  --! data width in bits
  constant DATA_WIDTH : positive := 16;  
  
  --------------------
  -- WRITE
  --------------------

  --! Write port channel control and data
  type r_ram_arbiter_wr_port_tx is
  record
    --! start address (must be valid at rising edge of frame signal)
    cfg_addr_first : unsigned(ADDR_WIDTH-1 downto 0); 
    --! last address before wrap (must be valid at rising edge of frame signal)
    cfg_addr_last : unsigned(ADDR_WIDTH-1 downto 0); 
    --! '1'=single-shot mode , '0'=continuous with wrap (must be valid at rising edge of frame signal)
    cfg_single_shot : std_logic;
    --! channel frame, start=rising edge, stop=falling edge 
    frame : std_logic;
    --! write data valid
    data_vld : std_logic;
    --! write data
    data : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record;
  type a_ram_arbiter_wr_port_tx is array(integer range <>) of r_ram_arbiter_wr_port_tx; 
  function RESET(x:r_ram_arbiter_wr_port_tx) return r_ram_arbiter_wr_port_tx;
  function RESET(x:a_ram_arbiter_wr_port_tx) return a_ram_arbiter_wr_port_tx;
--  constant DEFAULT_RAM_ARBITER_WR_PORT_TX : r_ram_arbiter_wr_port_tx := (
--    cfg_addr_first => (others=>'-'),
--    cfg_addr_last => (others=>'-'),
--    cfg_single_shot => '0',
--    frame => '0',
--    data_vld => '0',
--    data => (others=>'-')
--  );
  

  --! Write port channel status
  type r_ram_arbiter_wr_port_rx is
  record
    --! channel active
    active : std_logic;
    --! write pointer wrapped at least once (sticky bit)
    wrap : std_logic;
    --! TX input (valid) overflow
    tx_ovfl : std_logic;
    --! TX FIFO overflow
    fifo_ovfl : std_logic;
    --! current write pointer (next address)
    addr_next : unsigned(ADDR_WIDTH-1 downto 0);
  end record;
  type a_ram_arbiter_wr_port_rx is array(integer range <>) of r_ram_arbiter_wr_port_rx; 
  function RESET(x:r_ram_arbiter_wr_port_rx) return r_ram_arbiter_wr_port_rx;
  function RESET(x:a_ram_arbiter_wr_port_rx) return a_ram_arbiter_wr_port_rx;
--  constant DEFAULT_RAM_ARBITER_WR_PORT_RX : r_ram_arbiter_wr_port_rx := (
--    active => '0',
--    wrap => '0',
--    tx_ovfl => '0',
--    fifo_ovfl => '0',
--    addr_next => (others=>'0')
--  );

  --------------------
  -- READ
  --------------------

  --! Read port channel control and request
  type r_ram_arbiter_rd_port_tx is
  record
    --! start address (requires rising edge of frame signal)
    cfg_addr_first : unsigned(ADDR_WIDTH-1 downto 0); 
    --! last address before wrap (requires rising edge of frame signal)
    cfg_addr_last : unsigned(ADDR_WIDTH-1 downto 0); 
    --! channel frame, start=rising edge, stop=falling edge 
    frame : std_logic;
    --! read data request
    request : std_logic;
  end record;
  type a_ram_arbiter_rd_port_tx is array(integer range <>) of r_ram_arbiter_rd_port_tx; 
  constant DEFAULT_RAM_ARBITER_RD_PORT_TX : r_ram_arbiter_rd_port_tx := (
    cfg_addr_first => (others=>'-'),
    cfg_addr_last => (others=>'-'),
    frame => '0',
    request => '0'
  );

  --! Read port channel data and status
  type r_ram_arbiter_rd_port_rx is
  record
    --! channel active
    active : std_logic;
    --! read pointer wrapped at least once (sticky bit)
    wrap : std_logic;
    --! TX input (request) overflow
    tx_ovfl : std_logic;
    --! TX FIFO (request) overflow
    fifo_ovfl : std_logic;
    --! current read pointer (next address)
    addr_next : unsigned(ADDR_WIDTH-1 downto 0);
    --! read data valid
    data_vld : std_logic;
    --! read data
    data : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record;
  type a_ram_arbiter_rd_port_rx is array(integer range <>) of r_ram_arbiter_rd_port_rx; 
  constant DEFAULT_RAM_ARBITER_RD_PORT_RX : r_ram_arbiter_rd_port_rx := (
    active => '0',
    wrap => '0',
    tx_ovfl => '0',
    fifo_ovfl => '0',
    addr_next => (others=>'0'),
    data_vld => '0',
    data => (others=>'-')
  );


end package;

package body ram_arbiter_pkg is

  function RESET(x:r_ram_arbiter_wr_port_tx)
  return r_ram_arbiter_wr_port_tx is
    variable res : r_ram_arbiter_wr_port_tx;
--    -- VHDL-2008
--    variable res : x'subtype;
--    variable res : r_ram_arbiter_wr_port_tx(
--                     cfg_addr_first(x.cfg_addr_first'range),
--                     cfg_addr_last(x.cfg_addr_last'range),
--                     data(x.data'range) );
  begin
    res.data := (others=>'-');
    res.cfg_addr_first := (others=>'-');
    res.cfg_addr_last := (others=>'-');
--    res.data := (x.data'range=>'-');
--    res.cfg_addr_first := (x.cfg_addr_first'range=>'-');
--    res.cfg_addr_last := (x.cfg_addr_last'range=>'-');
    res.cfg_single_shot := '0';
    res.frame := '0';
    res.data_vld := '0';
    return res;
  end function;

  function RESET(x:a_ram_arbiter_wr_port_tx)
  return a_ram_arbiter_wr_port_tx is
    variable res : a_ram_arbiter_wr_port_tx(x'range);
--    -- VHDL-2008
--    variable res : x'subtype;
--    variable res : x'subtype(x'range);
--    variable res : a_ram_arbiter_wr_port_tx(x'range)(
--                     cfg_addr_first(x(x'low).cfg_addr_first'range),
--                     cfg_addr_last(x(x'low).cfg_addr_last'range),
--                     data(x(x'low).data'range) );
  begin
    for i in x'range loop res(i):=RESET(x(i)); end loop;  
    return res;
  end function;


  function RESET(x:r_ram_arbiter_wr_port_rx)
  return r_ram_arbiter_wr_port_rx is
    variable res : r_ram_arbiter_wr_port_rx;
  begin
    res.active := '0';
    res.wrap := '0';
    res.tx_ovfl := '0';
    res.fifo_ovfl := '0';
    res.addr_next := (others=>'0');
    return res;
  end function;

  function RESET(x:a_ram_arbiter_wr_port_rx)
  return a_ram_arbiter_wr_port_rx is
    variable res : a_ram_arbiter_wr_port_rx(x'range);
  begin
    for i in x'range loop res(i):=RESET(x(i)); end loop;  
    return res;
  end function;
  
end package body;
