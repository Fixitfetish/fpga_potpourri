-------------------------------------------------------------------------------
--! @file       signed_add_accu.behave.vhdl
--! @author     Fixitfetish
--! @date       19/Oct/2019
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension.all;
 use baselib.ieee_extension_types.all;


--! @brief Logic-based implementation of the entity signed_add_accu which is also the behavioral model.
--! 
architecture behave of signed_add_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_add_accu(behave)";

  -- width of A inputs
  constant A_WIDTH : positive := a(a'low)'length;

  -- width of Z inputs
  constant Z_WIDTH : positive := z(z'low)'length;

  -- largest input width, i.e. maximum width of inputs A and Z
  constant MAX_INPUT_WIDTH : positive := MAXIMUM(A_WIDTH,Z_WIDTH);

  -- derived constants
  constant ACCU_USED_WIDTH : positive := MAX_INPUT_WIDTH + GUARD_BITS;
  constant OUTPUT_WIDTH : positive := result(result'low)'length;

  -- A input register pipeline
  type r_ireg is
  record
    rst  : std_logic;
    vld  : std_logic;
    aux  : std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0);
    clr  : std_logic;
    a    : signed_vector(0 to NUM_ACCU-1)(A_WIDTH-1 downto 0);
  end record;
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG_A downto 0);

  -- Z logic input register pipeline
  type r_z_ireg is
  record
    z : signed_vector(0 to NUM_ACCU-1)(Z_WIDTH-1 downto 0);
  end record;
  type array_z_ireg is array(integer range <>) of r_z_ireg;
  signal z_ireg : array_z_ireg(NUM_INPUT_REG_Z downto 0);

  signal accu : signed_vector(0 to NUM_ACCU-1)(ACCU_USED_WIDTH-1 downto 0);
  signal accu_vld : std_logic;
  signal accu_aux : std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0);

  signal result_i : signed_vector(0 to NUM_ACCU-1)(OUTPUT_WIDTH-1 downto 0);
  signal result_vld_i, result_ovf_i : std_logic_vector(0 to NUM_ACCU-1);
  signal result_aux_i : slv_array(0 to NUM_ACCU-1)(NUM_AUXILIARY_BITS-1 downto 0);

  -- debug
  signal r0,r1 : signed(OUTPUT_WIDTH-1 downto 0);

begin

  -- debug
  r0 <= result_i(0);
  r1 <= result_i(1);


  -- A input pipeline
  ireg(NUM_INPUT_REG_A).rst <= rst;
  ireg(NUM_INPUT_REG_A).clr <= clr;
  ireg(NUM_INPUT_REG_A).vld <= vld;
  ireg(NUM_INPUT_REG_A).aux <= aux;
  ireg(NUM_INPUT_REG_A).a <= a; -- includes range conversion
  g_a_in : if NUM_INPUT_REG_A>=1 generate
   gk : for k in 1 to NUM_INPUT_REG_A generate
   begin
    p_ce : process(clk)
    begin
      if rising_edge(clk) then
--        for k in 1 to NUM_INPUT_REG_A loop -- GHDL 0.36 sim issue
          if rst/='0' then
            ireg(k-1).vld <= '0';
            ireg(k-1).clr <= '1';
            ireg(k-1).aux <= (others=>'0');
          elsif clkena='1' then
            ireg(k-1) <= ireg(k);
          end if;
--        end loop;
      end if;
    end process;
   end generate;
  end generate;


  -- Z input pipeline
  z_ireg(NUM_INPUT_REG_Z).z <= z; -- includes range conversion
  g_z_in : if NUM_INPUT_REG_Z>=1 generate
   gk : for k in 1 to NUM_INPUT_REG_Z generate
  begin
    p_ce : process(clk)
    begin
      if rising_edge(clk) then
--        for k in 1 to NUM_INPUT_REG_Z loop -- GHDL 0.36 sim issue
          if clkena='1' then
            z_ireg(k-1) <= z_ireg(k);
          end if;
--        end loop;
      end if;
    end process;
   end generate;
  end generate;


  -- accumulation
  p_accu : process(clk)
    variable v_az : signed(ACCU_USED_WIDTH-1 downto 0); -- intermediate result
  begin
    if rising_edge(clk) then
     if clkena='1' then
       for n in 0 to NUM_ACCU-1 loop
         v_az := resize(ireg(0).a(n),ACCU_USED_WIDTH) + resize(z_ireg(0).z(n),ACCU_USED_WIDTH);
         if ireg(0).clr='1' then
           if ireg(0).vld='1' then
             accu(n) <= v_az;
           else
             accu(n) <= (others=>'0');
           end if;
         else  
           if ireg(0).vld='1' then
             accu(n) <= accu(n) + v_az;
           end if;
         end if;
       end loop;
     end if; -- clock enable
    end if; -- clock
  end process;


  p_ctrl : process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        accu_vld <= '0';
        accu_aux <= (others=>'0');
      elsif clkena='1' then
        accu_vld <= ireg(0).vld;
        accu_aux <= ireg(0).aux;
      end if; -- clock enable
    end if; -- clock
  end process;


  -- right-shift and clipping
  gn : for n in 0 to NUM_ACCU-1 generate
    i_out : entity work.signed_output_logic
    generic map(
      PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => OUTPUT_ROUND,
      OUTPUT_CLIP        => OUTPUT_CLIP,
      OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW,
      NUM_AUXILIARY_BITS => NUM_AUXILIARY_BITS
    )
    port map (
      clk         => clk,
      rst         => rst,
      clkena      => clkena,
      dsp_out     => accu(n),
      dsp_out_vld => accu_vld,
      dsp_out_aux => accu_aux,
      result      => result_i(n),
      result_vld  => result_vld_i(n),
      result_ovf  => result_ovf_i(n),
      result_aux  => result_aux_i(n)
    );
  end generate;


  result <= result_i;
  result_vld <= result_vld_i(0); -- same for all
  result_aux <= result_aux_i(0); -- same for all
  result_ovf <= result_ovf_i;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_A + NUM_OUTPUT_REG;

end architecture;
