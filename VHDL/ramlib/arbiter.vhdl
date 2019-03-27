-------------------------------------------------------------------------------
--! @file       arbiter.vhdl
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

--! @brief Arbiter logic
--!
entity arbiter is
generic (
  --! @brief If true then rightmost LSB of request input has highest priority.
  --! Otherwise the leftmost MSB of request input has highest priority.
  --! 
  --! Request are granted according to the selected scheduling discipline.
  --! An additional priority handling is required if multiple requests occur at the same time.
  --! By default the leftmost MSB of the request input is given priority.
  --! Hence, if the request input has TO direction then the lowest index has the highest priority.
  --! And if the request input has DOWNTO direction then the highest index has the highest priority.
  --! If the rightmost LSB is given priority then priorities are inverted. 
  RIGHTMOST_REQUEST_FIRST : boolean := false;
  --! @brief Request inputs are pulses of one cycle duration and not high while waiting for a grant.
  --!
  --! If false then request must be cleared after grant (acknowledge mode).
  --! If true then every occurrence of request='1' is counted as a new request (continuous mode).
  --! NOTE: In continuous mode there is the risk of request overflow/loss when a new request occur
  --! though a pending request has not yet been granted.
  REQUEST_PULSE : boolean := false;
  --! Grant output port is registered, i.e. has one cycle delay
  OUTPUT_REG : boolean := false
);
port (
  --! Synchronous reset
  rst          : in  std_logic;
  --! Clock
  clk          : in  std_logic;
  --! Clock enable
  clk_ena      : in  std_logic;
  --! @brief Requests, one per port. Direction can be TO or DOWNTO.
  --! Requests are granted according to the scheduling discipline and the generic RIGHTMOST_REQUEST_FIRST .
  request      : in  std_logic_vector;
  --! Request overflow. Cannot occur in acknowledge mode.
  request_ovfl : out std_logic_vector;
  --! Still pending request waiting for grant
  pending      : out std_logic_vector;
  --! Grants, one per port. Only one port is granted at a time. Same range as request input.
  grant        : out std_logic_vector;
  --! Index according to range of grant output (and also of request input)
  grant_idx    : out integer range 0 to integer'high;
  --! Grant index valid. One of the bits of grant output ports is '1'.
  grant_vld    : out std_logic
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (request'low=0)
    report "ERROR in " & arbiter'INSTANCE_NAME & " Range of request input must have lowest index 0."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

--! @brief Fixed priority arbiter implementation.
--!
--! Compared to other scheduling disciplines a fixed priority arbiter is quite simple
--! to implement and does only require a few logic resources.
--! Hence, also the timing can be meet more easily. 
--! High priority requests are always granted first even though lower-priority
--! requests are still pending. For that reason, starvation of lower-priority
--! requests is possible when high-priority requests occur too frequently.
--!
--! This arbiter grants requests with leftmost index (MSB) first, that means
--! * If the request input has TO direction then the lowest index has highest priority.
--! * If the request input has DOWNTO direction then the highest index has highest priority.
--!
--! The priorities can be inverted by setting the generic RIGHTMOST_REQUEST_FIRST=true .
architecture prio of arbiter is

  constant NUM_PORTS : positive := request'length;

  signal pending_i : std_logic_vector(request'range);
  signal pending_new : std_logic_vector(request'range);
  signal req_ovfl_i : std_logic_vector(request'range);

  signal grant_i : std_logic_vector(request'range);
  signal grant_vld_i : std_logic;
  signal grant_idx_i : integer range 0 to NUM_PORTS-1 := 0;
  signal temp_grant_idx : integer range -1 to NUM_PORTS-1 := -1;

begin

  g_pulse_off : if not REQUEST_PULSE generate
    pending_i <= request;
    req_ovfl_i <= (others=>'0');
  end generate;

  g_pulse_on : if REQUEST_PULSE generate
    p_pending : process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          pending_i <= (others=>'0');        
        elsif clk_ena='1' then
          for p in 0 to (NUM_PORTS-1) loop
            if grant_i(p)='1' then
              -- Reset pending bit if old pending request is granted.
              -- Set pending bit immediately again if new request occurs at the same time. 
              pending_i(p) <= request(p) and pending_i(p);
            elsif request(p)='1' then
              -- Set pending bit if request is not granted.
              pending_i(p) <= '1';
            end if;  
          end loop;
        end if; --reset
      end if; --clock
    end process;
    -- request input overflow detection
    req_ovfl_i <= pending_i and request and (not grant_i) when clk_ena='1' else (others=>'0'); 
  end generate;

  pending_new <= pending_i or request;

  g_msb : if RIGHTMOST_REQUEST_FIRST generate
    temp_grant_idx <= INDEX_OF_RIGHTMOST_ONE(pending_new);
  end generate;

  g_lsb : if not RIGHTMOST_REQUEST_FIRST generate  
    temp_grant_idx <= INDEX_OF_LEFTMOST_ONE(pending_new);
  end generate;

  p_grant : process(temp_grant_idx)
  begin
    grant_i <= (others=>'0'); -- default
    grant_idx_i <= 0;
    grant_vld_i <= '0';
    if temp_grant_idx/=-1 then
      grant_i(temp_grant_idx) <= '1';
      grant_idx_i <= temp_grant_idx;
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
