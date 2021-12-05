-------------------------------------------------------------------------------
--! @file       barrelshift16.behave.vhdl
--! @author     Fixitfetish
--! @date       02/May/2021
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

--! @brief This implementation is a behavioral model of the entity barrelshift16
--! for simulation.
--!
architecture behave of barrelshift16 is

  -- convert input to default range
  alias xdin : std_logic_vector(din'length-1 downto 0) is din;

  signal din_i : std_logic_vector(din'length+16-1 downto 0);
  signal shifter_in : std_logic_vector(din'length+16-1 downto 0);
  signal shift_i : unsigned(3 downto 0) := (others=>'0');
  signal shifter_in_vld : std_logic;

  signal shifter_out, dout_i : std_logic_vector(din'length-1 downto 0);

  signal dout_vld_i : std_logic;

  signal s : integer range 0 to 15;

begin

  g_lr : if LEFT_SHIFT generate
    g_cyclic: if CYCLIC generate
      din_i <= reverse(xdin(xdin'high downto xdin'high-15)) & reverse(xdin);
    else generate
      din_i <= reverse(ext) & reverse(xdin);
    end generate;
  else generate
    g_cyclic: if CYCLIC generate
      din_i <= xdin(15 downto 0) & xdin;
    else generate
      din_i <= ext & xdin;
    end generate;
  end generate;

  gin : if INPUT_REG generate
   p : process(clk)
   begin
    if rising_edge(clk) then
      if rst='1' then
        shift_i <= (others=>'0');
        shifter_in <= (others=>'0');
        shifter_in_vld <= '0';
      elsif ce='1' then
        shift_i <= shift;
        shifter_in <= din_i;
        shifter_in_vld <= din_vld;
      end if;
    end if;
   end process;
  else generate
    shift_i <= shift;
    shifter_in <= din_i;
    shifter_in_vld <= din_vld;
  end generate;

  -- shifter
  s <= to_integer(shift_i);
  shifter_out <= shifter_in(s+din'length-1 downto s);

  gpipe : if PIPE_REG generate
   p : process(clk)
   begin
    if rising_edge(clk) then
      if rst='1' then
        dout_i <= (others=>'0');
        dout_vld_i <= '0';
      elsif ce='1' then
        if LEFT_SHIFT then
          dout_i <= reverse(shifter_out);
        else
          dout_i <= shifter_out;
        end if;
        dout_vld_i <= shifter_in_vld;
      end if;
    end if;
   end process;
  else generate
    g_lr : if LEFT_SHIFT generate
      dout_i <= reverse(shifter_out);
    else generate
      dout_i <= shifter_out;
    end generate;
    dout_vld_i <= shifter_in_vld;
  end generate;

  gout : if OUTPUT_REG generate
   p : process(clk)
   begin
    if rising_edge(clk) then
      if rst='1' then
        dout <= (din'length-1 downto 0=>'0');
        dout_vld <= '0';
      elsif ce='1' then
        dout <= dout_i;
        dout_vld <= dout_vld_i;
      end if;
    end if;
   end process;
  else generate
    dout <= dout_i;
    dout_vld <= dout_vld_i;
  end generate;

end architecture;

