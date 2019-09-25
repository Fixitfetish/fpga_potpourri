-------------------------------------------------------------------------------
--! @file       arbiter_demux_single_to_stream.vhdl
--! @author     Fixitfetish
--! @date       24/Sep/2019
--! @version    0.51
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;

--! @brief Arbiter that demultiplexes single data words to multiple users.
--!
--! This arbiter has one input port and a definable number of user output ports.
--! Input data, e.g. read/completion data returned from a bus, is distributed back into
--! the corresponding user channel FIFOs.
--!
--! @image html arbiter_demux_single_to_stream.svg "" width=500px
--!
--! NOTES: TODO 
--! * User port 0 has the highest priority and user port NUM_PORTS-1 has the lowest priority.
--! * The data width of each user port, the bus port and the RAM is DATA_WIDTH.
--! * The overall used RAM depth is NUM_PORTS x 2^FIFO_DEPTH_LOG2 .
--! * This is a synchronous design. User and bus must run with the same clock.
--! * If only one user port is open/active then continuous streaming is possible.
--! * The arbiter intentionally excludes RAM address handling or similar to keep it more flexible. 
--! 
entity arbiter_demux_single_to_stream is
generic(
  --! Number of user ports
  NUM_PORTS : positive;
  --! FIFO/RAM data width. 
  DATA_WIDTH : positive;
  --! FIFO depth per user port. LOG2(depth) ensures that the depth is a power of 2.
  FIFO_DEPTH_LOG2 : positive;
  --! RAM primitive type ("block" or "ultra")
  RAM_TYPE : string := "block"
);
port(
  --! System clock
  clk                 : in  std_logic;
  --! Synchronous reset
  rst                 : in  std_logic;
  --! End of frame, last data of frame (current user ID)
  bus_out_eof         : in  std_logic;
  --! User ID of corresponding request user
  bus_out_usr_id      : in  unsigned(log2ceil(NUM_PORTS)-1 downto 0);
  --! Data input
  bus_out_data        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
  --! Data input valid
  bus_out_data_vld    : in  std_logic;
  --! User ready to accept read data
  usr_in_rdy          : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! User data acknowledge
  usr_out_ack         : in  std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'1');
  --! User completion data acknowledge overflow
  usr_in_ack_ovfl     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! Read completion data
  usr_in_data         : out std_logic_vector(DATA_WIDTH-1 downto 0);
  --! Read completion data valid
  usr_in_data_vld     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! End/last data of frame
  usr_in_data_eof     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! @brief FIFO overflow (one per input port)
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_fifo_ovfl    : out std_logic_vector(NUM_PORTS-1 downto 0)
);
end entity;

-------------------------------------------------------------------------------

--! @brief Shared-RAM implementation of the demultiplexing arbiter
--!
--! Each user port has its own FIFO within a shared RAM.
--! Hence, only one user after each other can retrieve data from the FIFO/RAM.
--!
--! This arbiter is a slightly simplified version of a general arbiter that efficiently uses FPGA
--! RAM resources. Instead of having separate independent FIFOs per user port a shared RAM
--! is used to hold the FIFOs of all user ports. Hence, FPGA memory blocks can be used more
--! efficiently, e.g. when FIFOs with small depth but large data width are required.
--!
--! @image html arbiter_demux_single_to_stream.svg "" width=500px
--!
--! As a drawback the following limitations need to be considered
--! * All users must run with the same clock.
--! * If N user ports are active each user can access the bus only every Nth cycle.
--!   For N>1 burst of usr_out_ack (consecutive cycles) are not allowed and cause acknowledgement overflows.
--! * The overall usr_out_ack rate (all ports) must match the bus rate.
--!   FIFO overflows will occur when the usr_out_ack goes low for too long.
--!
architecture shared_ram of arbiter_demux_single_to_stream is

  -- Width of FIFO/Port select signal
  constant FIFO_SEL_WIDTH : positive := log2ceil(NUM_PORTS);

  -----------------------
  -- Shared RAM (FIFO)
  -----------------------

  function RAM_INPUT_REGS return natural is
  begin
    if RAM_TYPE="ultra" then 
      return 2; -- Xilinx Ultra-RAM
    else
      return 1; -- standard Block-RAM
    end if;
  end function;

  function RAM_OUTPUT_REGS return natural is
  begin
    if RAM_TYPE="ultra" then 
      return 2; -- Xilinx Ultra-RAM
    else
      return 1; -- standard Block-RAM
    end if;
  end function;

  -- RAM read delay can be adjusted if another RAM/FIFO with more pipeline stages is used.
  constant RAM_READ_DELAY : natural := RAM_INPUT_REGS + RAM_OUTPUT_REGS;

  type r_cpl_fifo is
  record
    rst          : std_logic;
    wr_ena       : std_logic;
    wr_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    wr_full      : std_logic;
    wr_overflow  : std_logic;
    rd_ena       : std_logic;
    rd_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    rd_empty     : std_logic;
    rd_underflow : std_logic;
    level        : unsigned(FIFO_DEPTH_LOG2 downto 0);
  end record;
  type a_cpl_fifo is array(integer range <>) of r_cpl_fifo;
  signal cpl_fifo : a_cpl_fifo(0 to NUM_PORTS-1);

  -- Data width of the completion FIFO/RAM (data + EOF flag)
  constant RAM_DATA_WIDTH : positive := DATA_WIDTH + 1;

  -- Address width of the completion FIFO/RAM
  constant RAM_ADDR_WIDTH : positive := FIFO_SEL_WIDTH + FIFO_DEPTH_LOG2;

  type r_cpl_ram is
  record
    addr     : unsigned(RAM_ADDR_WIDTH-1 downto 0);
    addr_vld : std_logic;
    data     : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
    data_vld : std_logic;
  end record;
  signal cpl_ram_wr : r_cpl_ram;
  signal cpl_ram_rd : r_cpl_ram;
  signal cpl_ram_wr_addr : std_logic_vector(RAM_ADDR_WIDTH-1 downto 0); -- GHDL work-around
  signal cpl_ram_rd_addr : std_logic_vector(RAM_ADDR_WIDTH-1 downto 0); -- GHDL work-around

  type a_cpl_ram_rd_ena is array(integer range <>) of std_logic_vector(NUM_PORTS-1 downto 0);
  signal cpl_ram_rd_ena : a_cpl_ram_rd_ena(0 to RAM_READ_DELAY);

   -- Acknowledge/use pointer provided by FIFO logic and trigger RAM read request
  signal usr_req_ack : std_logic_vector(NUM_PORTS-1 downto 0);

  function get_next(pending:std_logic_vector) return std_logic_vector is
    variable res : std_logic_vector(NUM_PORTS-1 downto 0);
  begin
    res := (others=>'0');
    -- lowest index = highest priority
    for n in pending'low to pending'high loop
      if pending(n)='1' then
        res(n):='1'; return res;
      end if;
    end loop;
    return res;
  end function;

  function get_next(pending:std_logic_vector) return unsigned is
    variable sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  begin
    sel := (others=>'0');
    -- lowest index = highest priority
    for n in pending'low to pending'high loop
      if pending(n)='1' then
        sel := to_unsigned(n-pending'low,sel'length); return sel;
      end if;
    end loop;
    return sel;
  end function;


  -- GTKWave work-around
  signal cpl_ram_wr_addr_vld : std_logic;
  signal cpl_ram_wr_data     : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
  signal cpl_ram_wr_data_vld : std_logic;
  signal cpl_ram_rd_addr_vld : std_logic;
  signal cpl_ram_rd_data     : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
  signal cpl_ram_rd_data_vld : std_logic;

begin

  -- GTKWave work-around
  cpl_ram_wr_addr_vld <= cpl_ram_wr.addr_vld;
  cpl_ram_wr_data     <= cpl_ram_wr.data;
  cpl_ram_wr_data_vld <= cpl_ram_wr.data_vld;
  cpl_ram_rd_addr_vld <= cpl_ram_rd.addr_vld;
  cpl_ram_rd_data     <= cpl_ram_rd.data;
  cpl_ram_rd_data_vld <= cpl_ram_rd.data_vld;

  -----------------------------------------------------------------------------
  -- Completion FIFO
  -----------------------------------------------------------------------------

  p_sorter : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        cpl_ram_wr.addr_vld <= '0';
        cpl_ram_wr.data_vld <= '0';
        cpl_ram_wr.addr <= (others=>'-');
        cpl_ram_wr.data <= (others=>'-');
      else
        cpl_ram_wr.addr_vld <= bus_out_data_vld;
        cpl_ram_wr.data_vld <= bus_out_data_vld;
        cpl_ram_wr.addr(RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= bus_out_usr_id;
        cpl_ram_wr.addr(FIFO_DEPTH_LOG2-1 downto 0) <= cpl_fifo(to_integer(bus_out_usr_id)).wr_ptr;
        cpl_ram_wr.data <= bus_out_eof & bus_out_data;
      end if; --reset
    end if; --clock
  end process;

  g_fifo : for n in 0 to (NUM_PORTS-1) generate
  begin

    -- reset FIFO 
    cpl_fifo(n).rst <= rst; -- TODO also after frame when FIFO is empty
    cpl_fifo(n).wr_ena <= bus_out_data_vld when bus_out_usr_id=n else '0'; 
    
--    i_logic : entity ramlib.fifo_logic_sync
--    generic map(
--      FIFO_DEPTH => 2**FIFO_DEPTH_LOG2,
--      PROG_FULL_THRESHOLD => 0,
--      PROG_EMPTY_THRESHOLD => 0
--    )
--    port map(
--      clk           => clk,
--      rst           => cpl_fifo(n).rst,
--      wr_ena        => cpl_fifo(n).wr_ena,
--      wr_ptr        => cpl_fifo(n).wr_ptr,
--      wr_full       => cpl_fifo(n).wr_full,
--      wr_prog_full  => open,
--      wr_overflow   => cpl_fifo(n).wr_overflow,
--      rd_ena        => cpl_fifo(n).rd_ena,
--      rd_ptr        => cpl_fifo(n).rd_ptr,
--      rd_empty      => cpl_fifo(n).rd_empty,
--      rd_prog_empty => open,
--      rd_underflow  => cpl_fifo(n).rd_underflow,
--      level         => cpl_fifo(n).level
--    );

    i_logic : entity ramlib.fifo_logic_sync2
    generic map(
      MAX_FIFO_DEPTH_LOG2 => FIFO_DEPTH_LOG2
    )
    port map(
      clk                      => clk,
      rst                      => cpl_fifo(n).rst,
      cfg_fifo_depth_minus1    => to_unsigned(2**FIFO_DEPTH_LOG2-1, FIFO_DEPTH_LOG2),
      cfg_prog_full_threshold  => open,
      cfg_prog_empty_threshold => open,
      wr_ena                   => cpl_fifo(n).wr_ena,
      wr_ptr                   => cpl_fifo(n).wr_ptr,
      wr_full                  => cpl_fifo(n).wr_full,
      wr_prog_full             => open,
      wr_overflow              => cpl_fifo(n).wr_overflow,
      rd_ena                   => cpl_fifo(n).rd_ena,
      rd_ptr                   => cpl_fifo(n).rd_ptr,
      rd_empty                 => cpl_fifo(n).rd_empty,
      rd_prog_empty            => open,
      rd_underflow             => cpl_fifo(n).rd_underflow,
      level                    => cpl_fifo(n).level
    );

    usr_in_fifo_ovfl(n) <= cpl_fifo(n).wr_overflow;
    usr_in_rdy(n) <= not cpl_fifo(n).rd_empty;

    usr_req_ack(n) <= usr_out_ack(n) and (not cpl_fifo(n).rd_empty);
    cpl_fifo(n).rd_ena <= usr_req_ack(n);

  end generate;

  cpl_ram_wr_addr <= std_logic_vector(cpl_ram_wr.addr); -- GHDL work-around
  cpl_ram_rd_addr <= std_logic_vector(cpl_ram_rd.addr); -- GHDL work-around

  i_shared_ram : entity ramlib.ram_sdp
  generic map(
    WR_DATA_WIDTH => RAM_DATA_WIDTH,
    RD_DATA_WIDTH => RAM_DATA_WIDTH,
    WR_DEPTH => 2**RAM_ADDR_WIDTH,
    WR_USE_BYTE_ENABLE => false,
    WR_INPUT_REGS => RAM_INPUT_REGS,
    RD_INPUT_REGS => RAM_INPUT_REGS,
    RD_OUTPUT_REGS => RAM_OUTPUT_REGS,
    RAM_TYPE => RAM_TYPE,
    INIT_FILE => open
  )
  port map(
    wr_clk     => clk,
    wr_rst     => rst,
    wr_clk_en  => '1',
    wr_en      => cpl_ram_wr.addr_vld,
--    wr_addr    => std_logic_vector(cpl_ram_wr.addr),
    wr_addr    => cpl_ram_wr_addr, -- GHDL work-around
    wr_be      => open, -- unused
    wr_data    => cpl_ram_wr.data,
    rd_clk     => clk,
    rd_rst     => rst,
    rd_clk_en  => '1',
    rd_en      => cpl_ram_rd.addr_vld,
--    rd_addr    => std_logic_vector(cpl_ram_rd.addr),
    rd_addr    => cpl_ram_rd_addr, -- GHDL work-around
    rd_data    => cpl_ram_rd.data,
    rd_data_en => cpl_ram_rd.data_vld
  );

  p_output_demux : process(clk)
    type a_rd_ptr is array(integer range <>) of unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    variable v_cpl_rd_ptr : a_rd_ptr(NUM_PORTS-1 downto 0) := (others=>(others=>'-'));
    variable v_cpl_ack : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_pending : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_pending_new : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_ena : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_id : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then

      for n in 0 to (NUM_PORTS-1) loop
        v_cpl_ack(n) := usr_req_ack(n);
        if usr_req_ack(n)='1' then
          v_cpl_rd_ptr(n) := cpl_fifo(n).rd_ptr;
        end if;  
      end loop;

      v_cpl_rd_pending_new := v_cpl_ack or v_cpl_rd_pending;
      v_cpl_rd_ena := get_next(v_cpl_rd_pending_new);
      v_cpl_rd_id := get_next(v_cpl_rd_pending_new);

      if rst='1' then
        cpl_ram_rd.addr_vld <= '0';
        cpl_ram_rd.addr <= (others=>'-');

        usr_in_ack_ovfl <= (others=>'0');
        v_cpl_rd_pending := (others=>'0');

      else
        cpl_ram_rd.addr_vld <= slv_or(v_cpl_rd_ena);
        cpl_ram_rd.addr(RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= v_cpl_rd_id;
        cpl_ram_rd.addr(FIFO_DEPTH_LOG2-1 downto 0) <= v_cpl_rd_ptr(to_integer(v_cpl_rd_id));

        -- handling of pending bits and overflow errors
        usr_in_ack_ovfl <= v_cpl_rd_pending and v_cpl_ack;
        v_cpl_rd_pending := v_cpl_rd_pending_new and (not v_cpl_rd_ena);

      end if; 

      -- compensate CPL RAM delay
      cpl_ram_rd_ena(0) <= v_cpl_rd_ena;
      for n in 1 to RAM_READ_DELAY loop
        cpl_ram_rd_ena(n) <= cpl_ram_rd_ena(n-1);
      end loop;

    end if; --clock
  end process;

  -- all users directly connect to CPL RAM data output register
  usr_in_data <= cpl_ram_rd.data(usr_in_data'length-1 downto 0); -- without EOF flag!

  -- one data valid per user, only one user per cycle
  usr_in_data_vld <= cpl_ram_rd_ena(RAM_READ_DELAY);

  -- completion data end of frame (EOF)
  g_eof : for n in 0 to NUM_PORTS-1 generate 
    usr_in_data_eof(n) <= cpl_ram_rd_ena(RAM_READ_DELAY)(n) and cpl_ram_rd.data(cpl_ram_rd.data'high);
  end generate;

end architecture;
