-------------------------------------------------------------------------------
--! @file       enable_burst_generator.vhdl
--! @author     Fixitfetish
--! @date       02/Dec/2017
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

--! @brief The enable_burst_generator generates an enable rate with a definable
--! ratio (<=1) of the clock frequency. 
--! 
--! The enable rate is defined by the ratio of active high cycles N to
--! the overall cycles of a period D.
--! * D = fraction denominator, period in cycles, must 1 or greater 
--! * N = fraction numerator, number of high cycles, must be in range 0 to D
--!
--! A ratio of 1 (N=D) means that the generated enable signal will be always high.
--! A ratio of 0 (N=0, D>0) means that the generated enable signal will be always low.
--! Typically, when clock_ena=1, the enable output is high in the first cycle after reset.
--! With clock_ena=0 the generator can be paused.
--! A reset is required to reconfigure and/or restart the generator.
--!
--! Two modes are available
--! * Duty-Cycle : generates pulses of N cycles width with a period of D cycles.
--! * Equidistant : generates equally spaced enable pulses of 1 cycle length.
--!

entity enable_burst_generator is
  port(
    --! @brief Synchronous reset, high-active, is required to reconfigure and restart the generator.
    --! The generator starts immediately when then reset is released.
    reset        : in  std_logic;
    --! System clock
    clock        : in  std_logic;
    --! Clock enable, by default 1, set 0 to pause generator (enable_out=0) 
    clock_enable : in  std_logic := '1';
    --! Mode , 1=Equidistant , 0=Duty-Cycle (default)
    equidistant  : in  std_logic := '0';
    --! @brief Denominator of the division ratio, i.e. period in number of clock cycles.
    --! Must be 1 or greater. (change only takes effect in reset)
    denominator  : in  unsigned;
    --! @brief Numerator of the division ratio, i.e. number of ON cycles within the period.
    --! Cannot be larger than the denominator. (change only takes effect in reset)
    numerator    : in  unsigned;
    --! @brief In equidistant mode defines number of enables to generate. 
    --! In duty cycle mode defines number of periods to generate. 
    --! If 0 then enables are generated continuously. (change only takes effect in reset)
    burst_length : in  unsigned;
    --! Generated enable output
    enable_out   : out std_logic;
    --! @brief Status of enable counter, counter width is the same as the width
    --! of the burst_length input. The counter wraps when burst_length is set to 0.
    burst_count  : out unsigned;
    --! Status 1=active, 0=stopped
    active       : out std_logic
  );
end entity;

-------------------------------------------------------------------------------

--! @brief The enable_burst_generator generates an enable rate with a definable
--! ratio of the clock frequency. 
--!
--! In the duty cycle mode enable pulses of N cycles width with a period of D
--! cycles are generated.
--! The duty cycle is defined by any ratio N/D between 0 and 1.
--! With clock frequency C the resulting frequency of the enable signal is C/D.
--! Note that maximum possible resulting frequency is C/2.
--! In addition also a burst of enables can be generated.
--! The number of periods is defined by burst_length.
--! If the burst length is 1 or greater then the generator automatically stops
--! when the burst is complete. If the burst length is 0 then enables are
--! generated continuously.
--! 
--! Duty-Cycle mode examples for different clock frequencies and ratios
--! | Clock[MHz] | Numerator | Denominator | Duty-Cycle | Freq.[MHz] |
--! |:----------:|:---------:|:-----------:|:----------:|:----------:|
--! |        100 |         1 |           1 |    100.00% |      0.000 |  
--! |        100 |         1 |           2 |     50.00% |     50.000 |  
--! |        100 |        11 |          20 |     55.00% |      5.000 |  
--! |        200 |       192 |         625 |     30.72% |      0.320 |  
--! 
--! In the equidistant mode equally spaced enable pulses of 1 cycle length are generated.
--! With the clock frequency C the resulting average enable frequency is
--! C*N/D . Generated enable pulses are high-active and one clock cycle long. 
--! Note that the enables are pseudo equidistant and can jitter dependent on ratio.   
--! For ratios greater than 1/2 several enable pulses can merge into a single longer pulse. 
--! 
--! Equidistant mode examples for different clock frequencies and ratios
--! | Clock[MHz] | Numerator | Denominator | Enable Rate[MHz] |
--! |:----------:|:---------:|:-----------:|:----------------:|
--! |        100 |         1 |           1 |          100.000 |  
--! |        100 |         1 |           2 |           50.000 |  
--! |        100 |        11 |          20 |           55.000 |  
--! |        200 |       192 |         625 |           61.440 |  
--! 
--! In addition also a burst of enables can be generated.
--! The number of enables in a burst is defined by burst_length.
--! If the burst length is 1 or greater then the generator automatically stops
--! when the burst is complete. If the burst length is 0 then enables are
--! generated continuously.

architecture rtl of enable_burst_generator is
 
  -- derive counter width from numerator and denominator width
  function get_counter_width(n,d: integer) return integer is
    variable res : integer;
  begin
    if n > d then res:=n; else res:=d; end if;
    return res+1;
  end function;

  constant CNT_WIDTH : integer := get_counter_width(numerator'length,denominator'length);

  -- record to hold configuration parameters while generator is active
  type r_cfg is
  record
    is_single_shot : boolean;
    equidistant    : std_logic;
    burst_length   : unsigned(burst_length'length-1 downto 0);
    -- count minimum (duty-cycle) or count decrement (equidistant)
    cnt_min_decr   : signed(CNT_WIDTH-1 downto 0);
    -- count maximum (duty-cycle) or count increment (equidistant)
    cnt_max_incr   : signed(CNT_WIDTH-1 downto 0);
  end record;
  signal cfg : r_cfg;

  signal cnt : signed(CNT_WIDTH-1 downto 0);
  signal burst_count_i : unsigned(burst_length'length-1 downto 0);  
  signal active_i : std_logic;

begin

  p_gen : process(clock)
    variable v_enable : std_logic;
    variable v_incr : signed(CNT_WIDTH-1 downto 0);
    variable v_cnt_decr : signed(CNT_WIDTH-1 downto 0);
    variable v_cnt_max : signed(CNT_WIDTH-1 downto 0);
  begin
    if rising_edge(clock) then
      enable_out <= '0';
      v_cnt_decr := - signed(resize(numerator,CNT_WIDTH));
      v_cnt_max := signed(resize(numerator,CNT_WIDTH)) - 1;
      
      if reset='1' then
        -- reset and initialization
        if equidistant='1' then
          -- equally spaced enables, requires count increment/decrement
          cfg.cnt_max_incr <= signed(resize(denominator,CNT_WIDTH))
                            - signed(resize(numerator,CNT_WIDTH));
          cfg.cnt_min_decr <= v_cnt_decr;
          cnt <= v_cnt_decr; -- counter initialization
        else
          -- duty-cycle enable, requires count max/min 
          cfg.cnt_min_decr <= signed(resize(numerator,CNT_WIDTH))
                            - signed(resize(denominator,CNT_WIDTH));
          cfg.cnt_max_incr <= v_cnt_max;
          cnt <= v_cnt_max; -- counter initialization
        end if;  
        cfg.equidistant <= equidistant;
        cfg.is_single_shot <= (burst_length/=0);
        cfg.burst_length <= burst_length;
        burst_count_i <= (others=>'0');
        active_i <= '1';
        active <= '0';
        
      elsif clock_enable='1' then

        active <= active_i;

        if cfg.is_single_shot and burst_count_i=cfg.burst_length then
          -- stop generation after single-shot burst
          active_i <= '0';
        elsif active_i='1' then
          if cfg.equidistant='1' then
            -- equally spaced enables
            if cnt(cnt'left)='1' then 
              enable_out <= '1';
              v_incr := cfg.cnt_max_incr;
              burst_count_i <= burst_count_i + 1;
            else
              v_incr := cfg.cnt_min_decr;
            end if;
            cnt <= cnt + v_incr;
          else
            -- duty-cycle enable 
            enable_out <= not cnt(cnt'left);
            if cnt=cfg.cnt_min_decr then
              cnt <= cfg.cnt_max_incr;
              burst_count_i <= burst_count_i + 1;
            else
              cnt <= cnt - 1;
            end if;
          end if;
        end if;

      end if; -- reset, clock enable
    end if; -- clock
  end process;

  -- internal signals to output ports
  burst_count <= burst_count_i;
  
end architecture;
