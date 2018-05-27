library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

-- Arbiter for multiple write channels
-- Port 0 has the highest priority.

entity ram_arbiter_write is
generic(
  --! Number of input ports
  NUM_PORTS : positive;
  --! RAM data width at user input and RAM output ports
  DATA_WIDTH : positive;
  --! Data word address width at user input and RAM output ports
  ADDR_WIDTH : positive;
  --! Maximum length of output bursts in number of data words (or cycles)
  OUTPUT_BURST_SIZE : positive
);
port(
  --! System clock
  clk             : in  std_logic;
  --! Synchronous reset
  rst             : in  std_logic;
  --! User write input port(s)
  usr_wr_port_tx  : in  a_ram_arbiter_wr_port_tx(0 to NUM_PORTS-1);
  --! User write status output
  usr_wr_port_rx  : out a_ram_arbiter_wr_port_rx(0 to NUM_PORTS-1);
  --! RAM is ready to accept data input
  ram_wr_ready    : in  std_logic;
  --! RAM data word write address
  ram_wr_addr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
  --! RAM data word input
  ram_wr_data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
  --! RAM data word enable
  ram_wr_ena      : out std_logic;
  --! Marker for first data word of a burst with incrementing address
  ram_wr_first    : out std_logic;
  --! Marker for last data word of a burst with incrementing address
  ram_wr_last     : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of ram_arbiter_write is

--  signal arb_din         : slv_array(0 to NUM_PORTS-1)(15 downto 0);
  signal arb_din         : slv16_array(0 to NUM_PORTS-1);
  signal arb_din_frame   : std_logic_vector(NUM_PORTS-1 downto 0);
  signal arb_din_vld     : std_logic_vector(NUM_PORTS-1 downto 0);
  signal arb_din_ovf     : std_logic_vector(NUM_PORTS-1 downto 0);
  signal arb_dout_rdy    : std_logic;
  signal arb_dout        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal arb_dout_ena    : std_logic;
  signal arb_dout_first  : std_logic;
  signal arb_dout_last   : std_logic;
  signal arb_dout_idx    : unsigned(log2ceil(NUM_PORTS)-1 downto 0);
  signal arb_dout_vld    : std_logic_vector(NUM_PORTS-1 downto 0);
  signal arb_dout_frame  : std_logic_vector(NUM_PORTS-1 downto 0);
  signal arb_fifo_ovf    : std_logic_vector(NUM_PORTS-1 downto 0);

  signal arb_din_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);
  signal arb_dout_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);

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

  g_in : for n in 0 to NUM_PORTS-1 generate
    -- TX
    arb_din_frame(n) <= usr_wr_port_tx(n).frame;
--    din_vld(n) <= usr_wr_port_tx(n).data_vld;
    arb_din_vld(n) <= usr_wr_port_tx(n).data_vld and addr_incr_active(n); -- TODO
    arb_din(n) <= usr_wr_port_tx(n).data;
    -- RX
--    usr_wr_port_rx(n).active <= dout_frame(n);
    usr_wr_port_rx(n).active <= addr_incr_active(n) and arb_dout_frame(n) when rising_edge(clk);
    usr_wr_port_rx(n).wrap <= wrap(n);
    usr_wr_port_rx(n).tx_ovfl <= arb_din_ovf(n);
    usr_wr_port_rx(n).fifo_ovfl <= arb_fifo_ovf(n);
    usr_wr_port_rx(n).addr_next <= addr_next(n);
  end generate;

  arb_dout_rdy <= ram_wr_ready when rising_edge(clk);

  i_fifo : entity ramlib.arbiter_write_single_to_burst
  generic map(
    NUM_PORTS  => NUM_PORTS,
    DATA_WIDTH => DATA_WIDTH,
    BURST_SIZE => OUTPUT_BURST_SIZE,
    FIFO_DEPTH_LOG2 => log2ceil(2*OUTPUT_BURST_SIZE)
  )
  port map (
    clk                     => clk,
    rst                     => rst,
    usr_out_req_frame       => arb_din_frame,
    usr_out_req_wr_ena      => arb_din_vld,
    usr_out_req_wr_data     => arb_din,
    usr_in_req_wr_ovfl      => arb_din_ovf,
    usr_in_req_wr_fifo_ovfl => arb_fifo_ovf,
    bus_out_req_rdy         => arb_dout_rdy,
    bus_in_req_wr_ena       => arb_dout_ena,
    bus_in_req_wr_data      => arb_dout,
    bus_in_req_first        => arb_dout_first,
    bus_in_req_last         => arb_dout_last,
    bus_in_req_port_frame   => arb_dout_frame,
    bus_in_req_port_ena     => arb_dout_vld,
    bus_in_req_port_idx     => arb_dout_idx
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
        arb_din_frame_q <= (others=>'1');

        arb_dout_frame_q <= (others=>'0');
        
      else    
        arb_din_frame_q <= arb_din_frame;
        arb_dout_frame_q <= arb_dout_frame;

        for n in 0 to (NUM_PORTS-1) loop
          if arb_din_frame(n)='1' and arb_din_frame_q(n)='0' then
            -- start channel, hold configuration        
            cfg(n).addr_first <= usr_wr_port_tx(n).cfg_addr_first;
            cfg(n).addr_last <= usr_wr_port_tx(n).cfg_addr_last;
            cfg(n).single_shot <= usr_wr_port_tx(n).cfg_single_shot;
            -- reset address
            wrap(n) <= '0';    
            addr_next(n) <= usr_wr_port_tx(n).cfg_addr_first;
            addr_incr_active(n) <= '1';

          elsif arb_dout_frame(n)='0' and arb_dout_frame_q(n)='1' then
            -- end of channel        
            addr_incr_active(n) <= '1';

          elsif arb_dout_vld(n)='1' and addr_incr_active(n)='1' then
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

  p_out : process(clk)
    variable v_active : std_logic;
    variable v_single_shot : std_logic;
    variable v_addr : unsigned(ADDR_WIDTH-1 downto 0); 
  begin
    if rising_edge(clk) then
      if rst='1' then
        ram_wr_ena <= '0';
        ram_wr_first <= '0';
        ram_wr_last <= '0';
        ram_wr_addr <= (others=>'-');
        ram_wr_data <= (others=>'-');
        
      else
        v_active := addr_incr_active(to_integer(arb_dout_idx));
        v_single_shot := cfg(to_integer(arb_dout_idx)).single_shot;
        v_addr := addr_next(to_integer(arb_dout_idx));

        ram_wr_ena <= arb_dout_ena and v_active;
        ram_wr_first <= arb_dout_first and v_active;
        if v_single_shot='1' and v_addr=cfg(to_integer(arb_dout_idx)).addr_last then
          -- always set last flag for last write of single-shot
          ram_wr_last <= v_active;
        else
          ram_wr_last <= arb_dout_last and v_active;
        end if;
        ram_wr_addr <= std_logic_vector(v_addr);
        ram_wr_data <= arb_dout;
      end if;
    end if;    
  end process;

end architecture;
