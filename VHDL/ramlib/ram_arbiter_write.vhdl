-------------------------------------------------------------------------------
--! @file       ram_arbiter_write.vhdl
--! @author     Fixitfetish
--! @date       09/Jun/2018
--! @version    0.60
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

--! @brief Arbiter that transforms single write requests from multiple user ports
--! to write request bursts at the single RAM port.
--!
--! This arbiter has a definable number of user ports and one RAM port.
--! The output port provides sequential bursts of data words for each input port.
--! The burst size is configurable but the same for all.
--! 
--! NOTES: 
--! * User input port 0 has the highest priority and user input port NUM_PORTS-1 has the lowest priority.
--! * The data width of each user port, the RAM port is DATA_WIDTH.
--! * If only one user port is open/active then continuous streaming is possible.
--!
--! Signal Prefix Naming (also useful for record mapping):
--! * usr_out : user output port, signals that the user generate (e.g. requests)
--! * usr_in : user input port, signals that the user receives (e.g. status)
--! * ram_out : ram output port, signals that are orginated by the ram (e.g. status or read data)
--! * ram_in : ram input port, signals that feed the bus (e.g. write/read requests)
--!
--! For details refer to the entity arbiter_mux_stream_to_burst which is used for this implementation.
--! Also consider using the optional entity ram_arbiter_write_data_width_adapter at the user interface
--! to adapt different user data widths to the RAM width.
--!  
--! @image html ram_arbiter_write.svg "" width=500px
--!
entity ram_arbiter_write is
generic(
  --! Number of user input ports
  NUM_PORTS : positive;
  --! RAM data width at user input and RAM output ports
  DATA_WIDTH : positive;
  --! Data word address width at user input and RAM output ports
  ADDR_WIDTH : positive;
  --! Maximum length of bursts in number of data word requests (or cycles)
  BURST_SIZE : positive
);
port(
  --! System clock
  clk              : in  std_logic;
  --! Synchronous reset
  rst              : in  std_logic;
  --! User write input port(s)
  usr_out_port     : in  a_ram_arbiter_usr_out_port(0 to NUM_PORTS-1);
  --! User write status output
  usr_in_port      : out a_ram_arbiter_usr_in_port(0 to NUM_PORTS-1);
  --! RAM is ready to accept data input
  ram_out_rdy      : in  std_logic;
  --! RAM request address
  ram_in_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
  --! RAM request enable
  ram_in_ena       : out std_logic;
  --! Marker for first request of a burst with incrementing address
  ram_in_first     : out std_logic;
  --! Marker for last request of a burst with incrementing address
  ram_in_last      : out std_logic;
  --! Write data to RAM
  ram_in_data      : out std_logic_vector(DATA_WIDTH-1 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of ram_arbiter_write is

--  signal mux_usr_req_data     : slv_array(0 to NUM_PORTS-1)(DATA_WIDTH-1 downto 0);
  signal mux_usr_req_data     : slv32_array(0 to NUM_PORTS-1);
  signal mux_usr_req_frame    : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_usr_req_ena      : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_usr_req_ovfl     : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_bus_req_rdy      : std_logic;
  signal mux_bus_req_data     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal mux_bus_req_data_vld : std_logic;
  signal mux_bus_req_sob      : std_logic;
  signal mux_bus_req_eob      : std_logic;
  signal mux_bus_req_eof      : std_logic;
  signal mux_bus_req_id       : unsigned(log2ceil(NUM_PORTS)-1 downto 0);
  signal mux_bus_req_ena      : std_logic;
  signal mux_bus_req_frame    : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_usr_req_fifo_ovfl: std_logic_vector(NUM_PORTS-1 downto 0);

  signal mux_usr_req_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_bus_req_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);

  type a_wr_addr is array(integer range <>) of unsigned(ADDR_WIDTH-1 downto 0);
  signal addr_next : a_wr_addr(NUM_PORTS-1 downto 0);
  signal addr_incr_active : std_logic_vector(NUM_PORTS-1 downto 0); 
  signal wrap : std_logic_vector(NUM_PORTS-1 downto 0); 

  type r_cfg is
  record
    --! start address (requires rising edge of frame signal)
    addr_first : unsigned(ADDR_WIDTH-1 downto 0); 
    --! last address before wrap (requires rising edge of frame signal)
    addr_last : unsigned(ADDR_WIDTH-1 downto 0); 
    --! '1'=single-shot mode , '0'=continuous with wrap (requires rising edge of frame signal)
    single_shot : std_logic;
  end record;
  constant DEFAULT_CFG : r_cfg := (
    addr_first=>(others=>'-'),
    addr_last=>(others=>'-'),
    single_shot => '-'
  );
  type a_cfg is array(integer range <>) of r_cfg;
  signal cfg : a_cfg(NUM_PORTS-1 downto 0); 

begin

  g_usr : for n in 0 to NUM_PORTS-1 generate
    -- TX
    mux_usr_req_frame(n) <= usr_out_port(n).req_frame;
    mux_usr_req_ena(n) <= usr_out_port(n).req_ena and addr_incr_active(n); -- TODO
    mux_usr_req_data(n) <= usr_out_port(n).req_data;
    -- RX
    usr_in_port(n).active <= addr_incr_active(n) and mux_bus_req_frame(n) when rising_edge(clk);
    usr_in_port(n).wrap <= wrap(n);
    usr_in_port(n).addr_next <= addr_next(n);
    usr_in_port(n).req_ovfl <= mux_usr_req_ovfl(n);
    usr_in_port(n).req_fifo_ovfl <= mux_usr_req_fifo_ovfl(n);
  end generate;

  mux_bus_req_rdy <= ram_out_rdy when rising_edge(clk);

  i_mux : entity ramlib.arbiter_mux_stream_to_burst
  generic map(
    NUM_PORTS  => NUM_PORTS,
    DATA_WIDTH => DATA_WIDTH,
    BURST_SIZE => BURST_SIZE,
    FIFO_DEPTH_LOG2 => log2ceil(2*BURST_SIZE),
    WRITE_ENABLE => true,
    POST_BURST_GAP_CYCLES => 0
  )
  port map (
    clk                     => clk,
    rst                     => rst,
    usr_out_req_frame       => mux_usr_req_frame,
    usr_out_req_ena         => mux_usr_req_ena,
    usr_out_req_wr_data     => mux_usr_req_data,
    usr_in_req_ovfl         => mux_usr_req_ovfl,
    usr_in_req_fifo_ovfl    => mux_usr_req_fifo_ovfl,
    bus_out_req_rdy         => mux_bus_req_rdy,
    bus_in_req_ena          => mux_bus_req_ena,
    bus_in_req_sob          => mux_bus_req_sob,
    bus_in_req_eob          => mux_bus_req_eob,
    bus_in_req_eof          => mux_bus_req_eof,
    bus_in_req_usr_id       => mux_bus_req_id,
    bus_in_req_usr_frame    => mux_bus_req_frame,
    bus_in_req_data         => mux_bus_req_data,
    bus_in_req_data_vld     => mux_bus_req_data_vld
  );

  p_addr : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        cfg <= (others=>DEFAULT_CFG);
        addr_next <= (others=>(others=>'-'));
        addr_incr_active <= (others=>'1');
        wrap <= (others=>'0');

        -- ensure no rising edge after reset, e.g. when din_frame is still '1'
        mux_usr_req_frame_q <= (others=>'1');

        mux_bus_req_frame_q <= (others=>'0');
        
      else    
        mux_usr_req_frame_q <= mux_usr_req_frame;
        mux_bus_req_frame_q <= mux_bus_req_frame;

        for n in 0 to (NUM_PORTS-1) loop
          if mux_usr_req_frame(n)='1' and mux_usr_req_frame_q(n)='0' then
            -- start channel, hold configuration        
            cfg(n).addr_first <= usr_out_port(n).cfg_addr_first;
            cfg(n).addr_last <= usr_out_port(n).cfg_addr_last;
            cfg(n).single_shot <= usr_out_port(n).cfg_single_shot;
            -- reset address
            wrap(n) <= '0';    
            addr_next(n) <= usr_out_port(n).cfg_addr_first;
            addr_incr_active(n) <= '1';

          elsif mux_bus_req_frame(n)='0' and mux_bus_req_frame_q(n)='1' then
            -- end of channel        
            addr_incr_active(n) <= '1';

          elsif mux_bus_req_ena='1' and mux_bus_req_id=n and addr_incr_active(n)='1' then
            -- address increment
            addr_next(n) <= addr_next(n) + 1;
            if addr_next(n)=cfg(n).addr_last then
              -- single-shot or continuous 
              if cfg(n).single_shot='0' then
                wrap(n) <= '1';    
                addr_next(n) <= cfg(n).addr_first;
              end if;
              -- set inactive when single-slot finished 
              addr_incr_active(n) <= not cfg(n).single_shot;
            end if;
          end if;
        end loop;
        
      end if;
    end if;    
  end process;

  p_ram_req : process(clk)
    variable v_active : std_logic;
    variable v_single_shot : std_logic;
    variable v_addr : unsigned(ADDR_WIDTH-1 downto 0); 
  begin
    if rising_edge(clk) then
      if rst='1' then
        ram_in_ena <= '0';
        ram_in_first <= '0';
        ram_in_last <= '0';
        ram_in_addr <= (others=>'-');
        ram_in_data <= (others=>'-');
        
      else
        v_active := addr_incr_active(to_integer(mux_bus_req_id));
        v_single_shot := cfg(to_integer(mux_bus_req_id)).single_shot;
        v_addr := addr_next(to_integer(mux_bus_req_id));

        ram_in_ena <= mux_bus_req_data_vld and v_active;
        ram_in_first <= mux_bus_req_sob and v_active;
        if v_single_shot='1' and v_addr=cfg(to_integer(mux_bus_req_id)).addr_last then
          -- always set last flag for last write of single-shot
          ram_in_last <= v_active;
        else
          ram_in_last <= mux_bus_req_eob and v_active;
        end if;
        ram_in_addr <= std_logic_vector(v_addr);
        ram_in_data <= mux_bus_req_data;
      end if;
    end if;    
  end process;

end architecture;
