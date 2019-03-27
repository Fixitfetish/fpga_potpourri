-------------------------------------------------------------------------------
--! @file       arbiter.fcfs.vhdl
--! @author     Fixitfetish
--! @date       28/Oct/2018
--! @version    0.10
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

--! @brief First-Come-First-Serve (FCFS) arbiter implementation.
--!
--! Pending requests are given priority before new requests.
--! The longer a request waits for a grant the higher becomes its priority.
--! Compared to other scheduling disciplines a FCFS arbiter is more difficult
--! to implement and requires more logic resources, especially when the number
--! of ports becomes larger. Hence, meeting the timing can be critical. 
--!
--! If requests occur at the time this arbiter by default grants requests with
--! leftmost index (MSB) first, that means
--! * If the request input has TO direction then the lowest index has highest priority.
--! * If the request input has DOWNTO direction then the highest index has highest priority.
--!
--! Inversion of priorities is possible by setting the generic RIGHTMOST_REQUEST_FIRST=true .
--!
architecture fcfs of arbiter is

  constant NUM_PORTS : positive := request'length;
  constant IDX_WIDTH : positive := log2ceil(NUM_PORTS);
  constant MAX_PRIO  : positive := NUM_PORTS-1;

  -- priority of pending requests
  signal prio : integer_vector(request'range);

  signal pending_i : std_logic_vector(request'range);
  signal req_ovfl_i : std_logic_vector(request'range);

  signal grant_i : std_logic_vector(request'range);
  signal grant_vld_i : std_logic;
  signal grant_idx_i : integer range 0 to NUM_PORTS-1 := 0;

  -- debug
  signal max_prio_idx : integer;
  signal prio0 : integer;
  signal prio1 : integer;
  signal prio2 : integer;
  signal prio3 : integer;

begin

  -- debug
  prio0 <= prio(0);
  prio1 <= prio(1);
  prio2 <= prio(2);
  prio3 <= prio(3);

  g_pulse_off : if not REQUEST_PULSE generate
    pending_i <= request;
    req_ovfl_i <= (others=>'0');
  end generate;

  g_pulse_on : if REQUEST_PULSE generate
    g_pending : for p in 0 to (NUM_PORTS-1) generate
      pending_i(p) <= to_01(prio(p)/=0);
    end generate;
    -- request input overflow detection
    req_ovfl_i <= pending_i and request and (not grant_i) when clk_ena='1' else (others=>'0'); 
  end generate;

  p_prio : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        prio <= (others=>0);
        
      elsif clk_ena='1' then
        
        for p in 0 to (NUM_PORTS-1) loop
          if grant_i(p)='1' then
            if (REQUEST_PULSE and request(p)='1' and pending_i(p)='1') then
              -- new request pulse occurs at same time when pending request is granted 
              prio(p) <= 1;
            else
              prio(p) <= 0;
            end if;
          elsif (not REQUEST_PULSE) and pending_i(p)='0' then
            -- clear priority if request has been canceled
            prio(p) <= 0;
          elsif (request(p)='1' or pending_i(p)='1') then
            -- increase priority of deferred request
            if prio(p)/=MAX_PRIO then
              prio(p) <= prio(p) + 1;
            end if;
          end if;  
        end loop;
        
      end if; --reset
    end if; --clock
  end process;


  p_grant : process(prio,request)
   variable v_req_prio_idx : integer;
   variable v_max_prio : integer;
   variable v_max_prio_idx : integer;
   variable v_prio_reverse : integer_vector(prio'reverse_range);
  begin
    grant_i <= (others=>'0'); -- default
    grant_idx_i <= 0; -- default
    grant_vld_i <= '0'; -- default
    if RIGHTMOST_REQUEST_FIRST then
      -- Reverse priorities without changing index to priority mapping!
      -- This is required because MAXIMUM returns leftmost maximum.
      v_prio_reverse := REVERSE(prio);
      MAXIMUM(din=>v_prio_reverse, max=>v_max_prio, idx=>v_max_prio_idx);
      v_req_prio_idx := INDEX_OF_RIGHTMOST_ONE(request);
    else
      MAXIMUM(din=>prio, max=>v_max_prio, idx=>v_max_prio_idx);
      v_req_prio_idx := INDEX_OF_LEFTMOST_ONE(request);
    end if;
    max_prio_idx <= v_max_prio_idx;
    if v_max_prio/=0 then
      -- first handle pending requests according priority/order
      grant_i(v_max_prio_idx) <= '1';
      grant_idx_i <= v_max_prio_idx;
      grant_vld_i <= '1';
    elsif v_req_prio_idx/=-1 then
      -- if there are no pending requests then handle new request
      grant_i(v_req_prio_idx) <= '1';
      grant_idx_i <= v_req_prio_idx;
      grant_vld_i <= '1';
    end if;
  end process;

  pending <= pending_i;

  g_oreg_off : if not OUTPUT_REG generate
    request_ovfl <= req_ovfl_i;
    grant <= grant_i;
    grant_idx <= grant_idx_i;
    grant_vld <= grant_vld_i;
  end generate;
  
  g_oreg_on : if OUTPUT_REG generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          request_ovfl <= (request_ovfl'range=>'0');
          grant <= (grant'range=>'0');
          grant_idx <= 0;
          grant_vld <= '0';
        elsif clk_ena='1' then
          request_ovfl <= req_ovfl_i;
          grant <= grant_i;
          grant_idx <= grant_idx_i;
          grant_vld <= grant_vld_i;
        end if;
      end if;
    end process;
  end generate;

end architecture;
