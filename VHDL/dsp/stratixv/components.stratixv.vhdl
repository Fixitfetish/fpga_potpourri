library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

-- This file is derived from the Altera simulation library.
-- Just the required MAC component declaration has been extracted.
--
-- NOTE: This file is needed only for analysis and synthesis. In this case the
-- file must be compiled into the "stratixv" library.
-- For simulation do NOT compile this file and use the corresponding precompiled
-- simulation library instead.

package stratixv_components is

  component stratixv_mac
  generic (
    accumulate_clock      : string  := "none";
    ax_clock              : string  := "none";
    ax_width              : natural := 16;
    ay_scan_in_clock      : string  := "none";
    ay_scan_in_width      : natural := 16;
    ay_use_scan_in        : string  := "false";
    az_clock              : string  := "none";
    az_width              : natural := 1;
    bx_clock              : string  := "none";
    bx_width              : natural := 16;
    by_clock              : string  := "none";
    by_use_scan_in        : string  := "false";
    by_width              : natural := 16;
    coef_a_0              : natural := 0;
    coef_a_1              : natural := 0;
    coef_a_2              : natural := 0;
    coef_a_3              : natural := 0;
    coef_a_4              : natural := 0;
    coef_a_5              : natural := 0;
    coef_a_6              : natural := 0;
    coef_a_7              : natural := 0;
    coef_b_0              : natural := 0;
    coef_b_1              : natural := 0;
    coef_b_2              : natural := 0;
    coef_b_3              : natural := 0;
    coef_b_4              : natural := 0;
    coef_b_5              : natural := 0;
    coef_b_6              : natural := 0;
    coef_b_7              : natural := 0;
    coef_sel_a_clock      : string  := "none";
    coef_sel_b_clock      : string  := "none";
    complex_clock         : string  := "none";
    delay_scan_out_ay     : string  := "false";
    delay_scan_out_by     : string  := "false";
    load_const_clock      : string  := "none";
    load_const_value      : natural := 0;
    lpm_type              : string  := "stratixv_mac";
    mode_sub_location     : natural := 0;
    negate_clock          : string  := "none";
    operand_source_max    : string  := "input";
    operand_source_may    : string  := "input";
    operand_source_mbx    : string  := "input";
    operand_source_mby    : string  := "input";
    operation_mode        : string  := "m18x18_sumof2";
    output_clock          : string  := "none";
    preadder_subtract_a   : string  := "false";
    preadder_subtract_b   : string  := "false";
    result_a_width        : natural := 64;
    result_b_width        : natural := 1;
    scan_out_width        : natural := 1;
    signed_max            : string  := "false";
    signed_may            : string  := "false";
    signed_mbx            : string  := "false";
    signed_mby            : string  := "false";
    sub_clock             : string  := "none";
    use_chainadder        : string  := "false"
  );
  port(
    accumulate : in  std_logic := '0';
    aclr       : in  std_logic_vector(1 downto 0) := (others => '0');
    ax         : in  std_logic_vector(ax_width-1 downto 0) := (others => '0');
    ay         : in  std_logic_vector(ay_scan_in_width-1 downto 0) := (others => '0');
    az         : in  std_logic_vector(az_width-1 downto 0) := (others => '0');
    bx         : in  std_logic_vector(bx_width-1 downto 0) := (others => '0');
    by         : in  std_logic_vector(by_width-1 downto 0) := (others => '0');
    chainin    : in  std_logic_vector(63 downto 0) := (others => '0');
    chainout   : out std_logic_vector(63 downto 0);
    cin        : in  std_logic := '0';
    clk        : in  std_logic_vector(2 downto 0) := (others => '0');
    coefsela   : in  std_logic_vector(2 downto 0) := (others => '0');
    coefselb   : in  std_logic_vector(2 downto 0) := (others => '0');
    complex    : in  std_logic := '0';
    cout       : out std_logic;
    dftout     : out std_logic;
    ena        : in  std_logic_vector(2 downto 0) := (others => '1');
    loadconst  : in  std_logic := '0';
    negate     : in  std_logic := '0';
    resulta    : out std_logic_vector(result_a_width-1 downto 0);
    resultb    : out std_logic_vector(result_b_width-1 downto 0);
    scanin     : in  std_logic_vector(ay_scan_in_width-1 downto 0) := (others => '0');
    scanout    : out std_logic_vector(scan_out_width-1 downto 0);
    sub        : in  std_logic := '0'
  );
  end component;

end package;

