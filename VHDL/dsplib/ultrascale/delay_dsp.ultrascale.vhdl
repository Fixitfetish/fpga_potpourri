-------------------------------------------------------------------------------
--! @file       delay_dsp.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       07/May/2017
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;

library unisim;
  use unisim.vcomponents.all;

--! @brief This is an implementation of the entity delay_dsp for Xilinx UltraScale.
--!
--! One Ultrascale DSP48E2 Slice supports two modes
--! * 3 pipeline stages with a maximum width of 48 bits (A:B mode), i.e. overall 144 single registers
--!   (2 Stages: A1/B1 -> P  ,  3 Stages: A1/B1 -> A2/B2 -> P)  
--! * 5 pipeline stages with a maximum width of 27 bits, i.e. overall 135 single registers
--!   (4 Stages: A1 -> AD -> M -> P  ,  5 Stages: A1 -> A2 -> AD -> M -> P)
--!
--! Hence, the number of registers corresponds to roughly 9 SliceL resources. 
--! Note that chaining of DSP cell is not wanted here to have at least some
--! flexibility for the DSP cell placement. Furthermore, chaining can not
--! improve the implementation of the delay pipeline.
--!
--! The constant flush reset value is provided through the round input RND.
--! Dependent on a delayed reset signal either RND or the data is output at P.
--! Hence, the DSP internal input and pipeline registers are actually not reset
--! but the register contents is discarded.
--!  
--! Refer to the following Xilinx documentation:
--! * UltraScale Architecture DSP48E2 Slice, UG579 (v1.3) November 24, 2015
--! * UltraScale Architecture Configurable Logic Block, UG574 (v1.5) February 28, 2017
--!
--! NOTE: Also consider delay pipelines based on SliceM or Block-RAM

architecture ultrascale of delay_dsp is

  -- width per DSP
  function wdsp return natural is
  begin
    if NUM_PIPELINE_STAGES<=3 then
      return 48;
    elsif NUM_PIPELINE_STAGES<=5 then
      return 27;
    else 
      report "ERROR in " & delay_dsp'INSTANCE_NAME & 
             " More than 5 pipeline stages are not supported."
      severity failure;  
      return 0; -- invalid
    end if;
  end function;

  -- number of DSPs
  function ndsp(din:std_logic_vector) return natural is
  begin
    if NUM_PIPELINE_STAGES<=3 then
      return (din'length+47)/48; -- ceil(din'length/48)
    elsif NUM_PIPELINE_STAGES<=5 then
      return (din'length+26)/27; -- ceil(din'length/27)
    else 
      return 0; -- invalid
    end if;
  end function;

  constant W : natural := wdsp;
  constant N : natural := ndsp(din);
  constant FLUSH_ENABLE : boolean := (FLUSH_RESET_VALUE'length=din'length);

  -- Enable/disable  A2 and B2 register stage
  function ABREG return natural is
  begin
    if NUM_PIPELINE_STAGES=3 or NUM_PIPELINE_STAGES=5 then
      return 2; else return 1; end if;
  end function;

  type t_p48 is array(0 to N-1) of std_logic_vector(47 downto 0);

  -- map reset value to RND inputs
  function get_rnd(val:std_logic_vector) return t_p48 is
    variable res : t_p48 := (others=>(others=>'0'));
    constant F : natural := val'length;
  begin
    if FLUSH_ENABLE then
      if N>=2 then for k in 0 to (N-2) loop
        res(k) := val((k+1)*W-1 downto k*W);
      end loop; end if;
      res(N-1)(F-1-(N-1)*W downto 0) := val(F-1 downto (N-1)*W);
    end if;
    return res;
  end function;

  constant RND : t_p48 := get_rnd(FLUSH_RESET_VALUE);
  signal pout : t_p48;

  signal prst : std_logic; -- pipeline reset
  signal pclkena : std_logic; -- pipeline clock enable
  signal rst_q : std_logic_vector(0 to NUM_PIPELINE_STAGES-2);

  signal opmode_w : std_logic_vector(1 downto 0);
  signal opmode_x : std_logic_vector(1 downto 0);    
  signal opmode_y : std_logic_vector(1 downto 0);    
  signal opmode_z : std_logic_vector(2 downto 0);    

begin

  prst <= '0' when FLUSH_ENABLE else rst;
  pclkena <= (rst or clkena) when (FLUSH_ENABLE and not FLUSH_WITH_CLKENA) else clkena;

  -- flush reset control pipeline
  rst_q(0) <= rst when FLUSH_ENABLE else '0';
  grst: if NUM_PIPELINE_STAGES>=3 generate
    rst_q(1 to NUM_PIPELINE_STAGES-2) <= rst_q(0 to NUM_PIPELINE_STAGES-3)
                                         when (rising_edge(clk) and pclkena='1');
--  begin
--    p_rst: process(clk)
--    begin
--      if rising_egde(clk) then
--        if pclkena='1' then
--          rst_q(1 to NUM_PIPELINE_STAGES-2) <= rst_q(0 to NUM_PIPELINE_STAGES-3);
--        end if;
--      end if;
--    end process;
  end generate;
  
  -- 3 pipeline stages with a maximum width of 48 bits (A:B mode)
  g3 : if NUM_PIPELINE_STAGES<=3 generate
    type t_pin is array(0 to N-1) of std_logic_vector(W-1 downto 0);
    signal pin : t_pin := (others=>(others=>'0'));
  begin
   
   gloop : for k in 0 to (N-1) generate
    -- map input port to DSP inputs
    g_first : if k<(N-1) generate
      pin(k) <= din((k+1)*W-1 downto k*W);
    end generate;
    g_last : if k=(N-1) generate
      pin(k)(din'length-1-k*W downto 0) <= din(din'length-1 downto k*W);
    end generate;

    -- Note: To avoid negation in logic the OPMODE X input must be inverted by DSP generic!
    opmode_x(0) <= rst_q(NUM_PIPELINE_STAGES-2); -- A:B when not reset
    opmode_x(1) <= rst_q(NUM_PIPELINE_STAGES-2); -- A:B when not reset
    opmode_y <= (others=>'0');
    opmode_w <= rst_q(NUM_PIPELINE_STAGES-2) & '0'; -- RND when reset
    opmode_z <= (others=>'0');
   
    dsp : DSP48E2
    generic map(
      -- Feature Control Attributes: Data Path Selection
      AMULTSEL                  => "A", -- don't use preadder feature
      A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
      B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
      PREADDINSEL               => "A", -- Selects input to preadder (A, B)
      RND                       => RND(k), -- Rounding Constant
      USE_MULT                  => "NONE", -- Select multiplier usage (MULTIPLY,DYNAMIC,NONE)
      USE_SIMD                  => "ONE48", -- SIMD selection(ONE48, FOUR12, TWO24)
      USE_WIDEXOR               => "FALSE", -- Use the Wide XOR function (FALSE, TRUE)
      XORSIMD                   => "XOR24_48_96", -- Mode of operation for the Wide XOR (XOR24_48_96, XOR12)
      -- Pattern Detector Attributes: Pattern Detection Configuration
      AUTORESET_PATDET          => "NO_RESET", -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
      AUTORESET_PRIORITY        => "RESET", -- Priority of AUTORESET vs.CEP (RESET, CEP).
      MASK                      => x"3FFFFFFFFFFF", -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN                   => x"000000000000", -- 48-bit pattern match for pattern detect
      SEL_MASK                  => "MASK", -- MASK, C, ROUNDING_MODE1, ROUNDING_MODE2
      SEL_PATTERN               => "PATTERN", -- Select pattern value (PATTERN, C)
      USE_PATTERN_DETECT        => "NO_PATDET", -- Enable pattern detect (NO_PATDET, PATDET)
      -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
      IS_ALUMODE_INVERTED       => "0000",
      IS_CARRYIN_INVERTED       => '0',
      IS_CLK_INVERTED           => '0',
      IS_INMODE_INVERTED        => "00000",
      IS_OPMODE_INVERTED        => "000000011", -- invert OPMODE X !
      IS_RSTALLCARRYIN_INVERTED => '0',
      IS_RSTALUMODE_INVERTED    => '0',
      IS_RSTA_INVERTED          => '0',
      IS_RSTB_INVERTED          => '0',
      IS_RSTCTRL_INVERTED       => '0',
      IS_RSTC_INVERTED          => '0',
      IS_RSTD_INVERTED          => '0',
      IS_RSTINMODE_INVERTED     => '0',
      IS_RSTM_INVERTED          => '0',
      IS_RSTP_INVERTED          => '0',
      -- Register Control Attributes: Pipeline Register Configuration
      ACASCREG                  => ABREG,-- 0,1 or 2
      ADREG                     => 0,-- 0 or 1
      ALUMODEREG                => 1, -- 0 or 1
      AREG                      => ABREG,-- 0,1 or 2
      BCASCREG                  => ABREG,-- 0,1 or 2
      BREG                      => ABREG,-- 0,1 or 2
      CARRYINREG                => 1,
      CARRYINSELREG             => 1,
      CREG                      => 1,
      DREG                      => 1, -- 0 or 1
      INMODEREG                 => 1, -- 0 or 1
      MREG                      => 0, -- 0 or 1
      OPMODEREG                 => 1, -- 0 or 1
      PREG                      => 1  -- 0 or 1
    ) 
    port map(
      CLK                => clk,
      -- Control: 1-bit (each) output: Control Inputs/Status Bits
      OVERFLOW           => open,
      PATTERNBDETECT     => open,
      PATTERNDETECT      => open,
      UNDERFLOW          => open,
      -- Cascade: 30-bit (each) input: Cascade Ports
      ACIN               => (others=>'0'), -- unused
      BCIN               => (others=>'0'), -- unused
      CARRYCASCIN        => '0', -- unused
      MULTSIGNIN         => '0', -- unused
      PCIN               => (others=>'0'),
      -- carry input
      ALUMODE            => "0000", -- always P = Z + (W + X + Y + CIN)
      INMODE             => (others=>'0'), -- irrelevant
      OPMODE(1 downto 0) => opmode_x, -- X=A:B  or X=0
      OPMODE(3 downto 2) => opmode_y, -- opmode_y, Y=0
      OPMODE(6 downto 4) => opmode_z, -- opmode_z, Z=0
      OPMODE(8 downto 7) => opmode_w, -- W=RND or W=0
      CARRYIN            => '0', -- unused
      CARRYINSEL         => "000", -- unused
      RSTALLCARRYIN      => '1', -- unused
      CECARRYIN          => '0', -- unused
      -- control input
      RSTALUMODE         => prst, -- TODO
      RSTCTRL            => prst, -- TODO
      RSTINMODE          => prst, -- TODO
      CEALUMODE          => pclkena,
      CECTRL             => pclkena, -- for opmode
      CEINMODE           => pclkena,
      -- input A
      A                  => pin(k)(47 downto 18),
      RSTA               => prst,
      CEA1               => pclkena,
      CEA2               => pclkena,
      -- input B
      B                  => pin(k)(17 downto  0),
      RSTB               => prst,
      CEB1               => pclkena,
      CEB2               => pclkena,
      -- input C 
      C                  => (others=>'0'), -- unused
      RSTC               => '1', -- unused
      CEC                => '0', -- unused
      -- input D/AD
      D                  => (others=>'0'), -- unused,
      RSTD               => '1', -- unused
      CED                => '0', -- unused
      CEAD               => '0', -- unused
      -- pipeline M
      RSTM               => '1', -- unused
      CEM                => '0', -- unused
      -- output P
      RSTP               => prst,
      CEP                => pclkena,
      P                  => pout(k),
      -- Data: 4-bit (each) output: Data Ports
      CARRYOUT           => open,
      XOROUT             => open,
      -- Cascade: 30-bit (each) output: Cascade Ports
      ACOUT              => open,
      BCOUT              => open,
      CARRYCASCOUT       => open,
      MULTSIGNOUT        => open,
      PCOUT              => open
    );
   end generate;
  end generate;

  -- 5 pipeline stages with a maximum width of 27 bits
  g5 : if NUM_PIPELINE_STAGES=4 or NUM_PIPELINE_STAGES=5 generate
    type t_pin is array(0 to N-1) of std_logic_vector(W-1 downto 0);
    signal pin : t_pin := (others=>(others=>'0'));
  begin
   
   gloop : for k in 0 to (N-1) generate
    -- map input port to DSP inputs
    g_first : if k<(N-1) generate
      pin(k) <= din((k+1)*W-1 downto k*W);
    end generate;
    g_last : if k=(N-1) generate
      pin(k)(din'length-1-k*W downto 0) <= din(din'length-1 downto k*W);
    end generate;

    -- Note: To avoid negation in logic the OPMODE bits 0=X0 and 2=Y(0)
    -- must be inverted by DSP generic!
    opmode_x <= '0' & rst_q(NUM_PIPELINE_STAGES-2); -- M when not reset
    opmode_y <= '0' & rst_q(NUM_PIPELINE_STAGES-2); -- M when not reset
    opmode_w <= rst_q(NUM_PIPELINE_STAGES-2) & '0'; -- RND when reset
    opmode_z <= (others=>'0');
   
    dsp : DSP48E2
    generic map(
      -- Feature Control Attributes: Data Path Selection
      AMULTSEL                  => "AD", -- use preadder feature
      A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
      B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
      PREADDINSEL               => "A", -- Selects input to preadder (A, B)
      RND                       => RND(k), -- Rounding Constant
      USE_MULT                  => "MULTIPLY", -- Select multiplier usage (MULTIPLY,DYNAMIC,NONE)
      USE_SIMD                  => "ONE48", -- SIMD selection(ONE48, FOUR12, TWO24)
      USE_WIDEXOR               => "FALSE", -- Use the Wide XOR function (FALSE, TRUE)
      XORSIMD                   => "XOR24_48_96", -- Mode of operation for the Wide XOR (XOR24_48_96, XOR12)
      -- Pattern Detector Attributes: Pattern Detection Configuration
      AUTORESET_PATDET          => "NO_RESET", -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
      AUTORESET_PRIORITY        => "RESET", -- Priority of AUTORESET vs.CEP (RESET, CEP).
      MASK                      => x"3FFFFFFFFFFF", -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN                   => x"000000000000", -- 48-bit pattern match for pattern detect
      SEL_MASK                  => "MASK", -- MASK, C, ROUNDING_MODE1, ROUNDING_MODE2
      SEL_PATTERN               => "PATTERN", -- Select pattern value (PATTERN, C)
      USE_PATTERN_DETECT        => "NO_PATDET", -- Enable pattern detect (NO_PATDET, PATDET)
      -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
      IS_ALUMODE_INVERTED       => "0000",
      IS_CARRYIN_INVERTED       => '0',
      IS_CLK_INVERTED           => '0',
      IS_INMODE_INVERTED        => "00000",
      IS_OPMODE_INVERTED        => "000000101", -- invert OPMODE bits of X and Y !
      IS_RSTALLCARRYIN_INVERTED => '0',
      IS_RSTALUMODE_INVERTED    => '0',
      IS_RSTA_INVERTED          => '0',
      IS_RSTB_INVERTED          => '0',
      IS_RSTCTRL_INVERTED       => '0',
      IS_RSTC_INVERTED          => '0',
      IS_RSTD_INVERTED          => '0',
      IS_RSTINMODE_INVERTED     => '0',
      IS_RSTM_INVERTED          => '0',
      IS_RSTP_INVERTED          => '0',
      -- Register Control Attributes: Pipeline Register Configuration
      ACASCREG                  => ABREG,-- 0,1 or 2
      ADREG                     => 1,-- 0 or 1
      ALUMODEREG                => 1, -- 0 or 1
      AREG                      => ABREG,-- 0,1 or 2
      BCASCREG                  => ABREG,-- 0,1 or 2
      BREG                      => ABREG,-- 0,1 or 2
      CARRYINREG                => 1,
      CARRYINSELREG             => 1,
      CREG                      => 1,
      DREG                      => 1, -- 0 or 1
      INMODEREG                 => 1, -- 0 or 1
      MREG                      => 1, -- 0 or 1
      OPMODEREG                 => 1, -- 0 or 1
      PREG                      => 1  -- 0 or 1
    ) 
    port map(
      CLK                => clk,
      -- Control: 1-bit (each) output: Control Inputs/Status Bits
      OVERFLOW           => open,
      PATTERNBDETECT     => open,
      PATTERNDETECT      => open,
      UNDERFLOW          => open,
      -- Cascade: 30-bit (each) input: Cascade Ports
      ACIN               => (others=>'0'), -- unused
      BCIN               => (others=>'0'), -- unused
      CARRYCASCIN        => '0', -- unused
      MULTSIGNIN         => '0', -- unused
      PCIN               => (others=>'0'),
      -- carry input
      ALUMODE            => "0000", -- always P = Z + (W + X + Y + CIN)
      INMODE             => (others=>'0'), -- A->AD->A_MULT and B->B_MULT
      OPMODE(1 downto 0) => opmode_x, -- X=M or X=0
      OPMODE(3 downto 2) => opmode_y, -- Y=M or Y=0
      OPMODE(6 downto 4) => opmode_z, -- opmode_z, Z=0
      OPMODE(8 downto 7) => opmode_w, -- W=RND or W=0
      CARRYIN            => '0', -- unused
      CARRYINSEL         => "000", -- unused
      RSTALLCARRYIN      => '1', -- unused
      CECARRYIN          => '0', -- unused
      -- control input
      RSTALUMODE         => prst,
      RSTCTRL            => prst,
      RSTINMODE          => prst,
      CEALUMODE          => pclkena,
      CECTRL             => pclkena, -- for opmode
      CEINMODE           => pclkena,
      -- input A
      A(29)              => pin(k)(26), -- dummy sign extension
      A(28)              => pin(k)(26), -- dummy sign extension
      A(27)              => pin(k)(26), -- dummy sign extension
      A(26 downto 0)     => pin(k),
      RSTA               => prst,
      CEA1               => pclkena,
      CEA2               => pclkena,
      -- input B
      B                  => "000000000000000001", -- constant 1
      RSTB               => prst,
      CEB1               => pclkena,
      CEB2               => pclkena,
      -- input C 
      C                  => (others=>'0'), -- unused
      RSTC               => '1', -- unused
      CEC                => '0', -- unused
      -- input D/AD
      D                  => (others=>'0'), -- unused,
      RSTD               => prst,
      CED                => '0', -- unused
      CEAD               => pclkena,
      -- pipeline M
      RSTM               => prst,
      CEM                => pclkena,
      -- output P
      RSTP               => prst,
      CEP                => pclkena,
      P                  => pout(k),
      -- Data: 4-bit (each) output: Data Ports
      CARRYOUT           => open,
      XOROUT             => open,
      -- Cascade: 30-bit (each) output: Cascade Ports
      ACOUT              => open,
      BCOUT              => open,
      CARRYCASCOUT       => open,
      MULTSIGNOUT        => open,
      PCOUT              => open
    );
   end generate;
  end generate;

  -- map DSP outputs to output port
  gout : for k in 0 to (N-1) generate
    -- complete DSP output
    g_first : if k<(N-1) generate
      dout((k+1)*W-1 downto k*W) <= pout(k)(W-1 downto 0);
    end generate;
    -- partial DSP output
    g_last : if k=(N-1) generate
      dout(dout'length-1 downto k*W) <= pout(k)(dout'length-1-k*W downto 0);
    end generate;
  end generate;

end architecture;
