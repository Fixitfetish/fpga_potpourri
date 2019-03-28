-------------------------------------------------------------------------------
--! @file       arbiter.rr.vhdl
--! @author     Fixitfetish
--! @date       27/Mar/2019
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

--! @brief Round-Robin (RR) arbiter implementation.
--!
architecture rr of arbiter is

  constant NUM_PORTS : positive := request'length;

  signal request_i : std_logic_vector(request'range);
  signal req_ovfl_i : std_logic_vector(request'range);

  signal pending_all : std_logic_vector(request'range);
  signal pending_mask : std_logic_vector(request'range);
  signal pending_sel : std_logic_vector(request'range);
  signal mask : std_logic_vector(request'range);

  signal grant_i : std_logic_vector(request'range);
  signal grant_vld_i : std_logic;
  signal grant_idx_i : natural range 0 to NUM_PORTS-1 := 0;

begin

  g_pulse_off : if not REQUEST_PULSE generate
    request_i <= request;
    req_ovfl_i <= (others=>'0');
  end generate;

  g_pulse_on : if REQUEST_PULSE generate
    p_pending : process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          request_i <= (others=>'0');
        elsif clk_ena='1' then
          for p in 0 to (NUM_PORTS-1) loop
            if grant_i(p)='1' then
              -- Clear request bit if old pending request is granted.
              -- Set request bit immediately again if new request pulse occurs at the same time. 
              request_i(p) <= request(p) and request_i(p);
            elsif request(p)='1' then
              -- Set request bit if request is not granted.
              request_i(p) <= '1';
            end if;  
          end loop;
        end if; --reset
      end if; --clock
    end process;
    -- request input overflow detection
    req_ovfl_i <= request_i and request and (not grant_i) when clk_ena='1' else (others=>'0'); 
  end generate;

  pending_all <= request_i or request;
  pending_mask <= pending_all and mask;
  pending_sel <= pending_all when pending_mask=(pending_mask'range=>'0') else pending_mask;
  

  p_grant : process(pending_sel)
   variable v_grant_idx : integer;
  begin
    grant_i <= MASK_RIGHTMOST_ONE(pending_sel);
    grant_idx_i <= 0; -- default
    grant_vld_i <= '0'; -- default

    v_grant_idx := INDEX_OF_RIGHTMOST_ONE(pending_sel);
    if v_grant_idx/=-1 then
      grant_idx_i <= v_grant_idx;
      grant_vld_i <= '1';
    end if;
  end process;

  p_mask : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        mask <= (others=>'1');
        
      elsif clk_ena='1' then
        
        if unsigned(pending_sel(NUM_PORTS-2 downto 0))=0 then
          -- start new round (after last request of round or when idle)
          mask <= (others=>'1');
        else
          -- mask remaining requests of current round
          mask <= ZEROS_RIGHT(grant_idx_i,NUM_PORTS-1) & '0';
--          mask(0) <= '0';
--          mask(NUM_PORTS-1 downto 1) <= ZEROS_RIGHT(grant_idx_i,NUM_PORTS-1);
        end if;
        
      end if; --reset
    end if; --clock
  end process;



  g_oreg_off : if not OUTPUT_REG generate
    request_ovfl <= req_ovfl_i;
    pending <= pending_all;
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
          pending <= (pending'range=>'0');
          grant <= (grant'range=>'0');
          grant_idx <= 0;
          grant_vld <= '0';
        elsif clk_ena='1' then
          request_ovfl <= req_ovfl_i;
          pending <= pending_all;
          grant <= grant_i;
          grant_idx <= grant_idx_i;
          grant_vld <= grant_vld_i;
        end if;
      end if;
    end process;
  end generate;

end architecture;
