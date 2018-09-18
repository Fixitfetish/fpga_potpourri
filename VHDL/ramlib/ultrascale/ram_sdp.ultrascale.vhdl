-------------------------------------------------------------------------------
--! @file       ram_sdp.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       15/Sep/2018
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;

--library xpm;
--  use xpm.vcomponents.all;

--! @brief Xilinx UltraScale-Plus specific implementation of the Simple Dual Port RAM.
--! 

architecture ultrascale of ram_sdp is

  --! Xilinx UltraScale+ specific RAM type for macro xpm_memory_sdpram
  function RAM_TYPE_ULTRASCALE return string is
  begin
    if RAM_TYPE="dist" then
      return "distributed";
    elsif RAM_TYPE="block" then
      return "block";
    elsif RAM_TYPE="ultra" then
      return "ultra";
    else
      -- pragma translate_off (Xilinx Vivado , Synopsys)
      report "Error " & ram_sdp'instance_name & ": Xilinx UltraScale+ only supports the RAM types 'dist' , 'block' and 'ultra' "
      severity failure;
      return "";
      -- pragma translate_on (Xilinx Vivado , Synopsys)
    end if;
  end function;

  --! number of RAM internal input registers (write and read port)
  function RAM_INPUT_REGS return positive is
  begin
    -- dependent on the RAM type always 1 or 2 input registers are required.
    if RAM_TYPE="ultra" then return 2; else return 1; end if;
  end function;

  --! Number of RAM internal output registers (read port only)
  function RAM_OUTPUT_REGS return natural is
  begin
    if RAM_TYPE="ultra" then
      -- Ultra-RAM allows up to 2 internal output registers
      if RD_OUTPUT_REGS<2 then return RD_OUTPUT_REGS; else return 2; end if;
    else
      -- Standard-RAM allows up to 1 internal output register
      if RD_OUTPUT_REGS<1 then return RD_OUTPUT_REGS; else return 1; end if;
    end if;
  end function;

  --! number of additional write input registers in logic
  constant WR_INPUT_REGS_LOGIC : natural := WR_INPUT_REGS - RAM_INPUT_REGS;

  --! number of additional read input registers in logic
  constant RD_INPUT_REGS_LOGIC : natural := RD_INPUT_REGS - RAM_INPUT_REGS;

  --! number of additional read output registers in logic
  constant RD_OUTPUT_REGS_LOGIC : natural := RD_OUTPUT_REGS - RAM_OUTPUT_REGS;
  
  --! overall read latency
  constant RD_LATENCY : natural := RD_INPUT_REGS + RD_OUTPUT_REGS;
  
  --! clocking mode for macro xpm_memory_sdpram
  function CLOCKING_MODE return string is
  begin
    if RAM_TYPE="ultra" then return "common_clock"; else return "independent_clock"; end if;
  end function;

  --! write mode for macro xpm_memory_sdpram
  function WRITE_MODE return string is
  begin
    if RAM_TYPE = "block" then
      return "write_first";
    elsif RAM_TYPE = "dist" then
      return "read_first";
    else
      return "no_change";
    end if;
  end function;

  --! XILINX UltraScale+ specific initialization file for macro xpm_memory_sdpram
  function INIT_FILE_ULTRASCALE return string is
  begin
    if INIT_FILE = "" then return "none"; else  return INIT_FILE & ".mem"; end if;
  end function;

  --! byte enable width
  function BYTE_WRITE_WIDTH return positive is
  begin
    if WR_USE_BYTE_ENABLE then return 8; else return WR_DATA_WIDTH; end if;
  end function;

  --! Write/byte enable width (write port only)
  constant WE_WIDTH : positive := (WR_DATA_WIDTH / BYTE_WRITE_WIDTH);

  type t_ram_addr_a is array(integer range <>) of std_logic_vector(ADDR_WIDTH-1 downto 0);
  -- write address input pipeline
  signal ram_addr_a  : t_ram_addr_a(WR_INPUT_REGS_LOGIC downto 0);

  type t_ram_din_a is array(integer range <>) of std_logic_vector(WR_DATA_WIDTH-1 downto 0);
  -- write data input pipeline
  signal ram_din_a  : t_ram_din_a(WR_INPUT_REGS_LOGIC downto 0);
  
  type t_ram_we_a is array(integer range <>) of std_logic_vector(WE_WIDTH-1 downto 0);
  -- write enable input pipeline
  signal ram_we_a : t_ram_we_a(WR_INPUT_REGS_LOGIC downto 0);
  
  type t_ram_addr_b is array(integer range <>) of std_logic_vector(ADDR_WIDTH-1 downto 0);
  -- read address input pipeline
  signal ram_addr_b  : t_ram_addr_b(RD_INPUT_REGS_LOGIC downto 0);

  type t_ram_dout_b is array(integer range <>) of std_logic_vector(RD_DATA_WIDTH-1 downto 0);
  -- read data output pipeline
  signal ram_dout_b  : t_ram_dout_b(0 to RD_OUTPUT_REGS_LOGIC);

  --! read enable pipeline
  signal rd_en_q : std_logic_vector(0 to RD_LATENCY);

begin

  ram_addr_a(0) <= wr_addr;
  ram_din_a(0) <= wr_data;
  
  g_be_off : if not WR_USE_BYTE_ENABLE generate
    ram_we_a(0)(0) <= wr_en;
  end generate;
  
  g_be_on : if WR_USE_BYTE_ENABLE generate
    g_we : for n in 0 to WE_WIDTH-1 generate
      ram_we_a(0)(n) <= wr_en and wr_be(n);
    end generate;
  end generate;

  g_in : if WR_INPUT_REGS_LOGIC>=1 generate
    g_loop : for n in 1 to WR_INPUT_REGS_LOGIC generate
      ram_addr_a(n) <= (others=>'0')   when (rising_edge(wr_clk) and wr_rst='1') else
                       ram_addr_a(n-1) when (rising_edge(wr_clk) and wr_clk_en='1');
      ram_din_a(n)  <= (others=>'-')   when (rising_edge(wr_clk) and wr_rst='1') else
                       ram_din_a(n-1)  when (rising_edge(wr_clk) and wr_clk_en='1');
      ram_we_a(n)   <= (others=>'0')   when (rising_edge(wr_clk) and wr_rst='1') else
                       ram_we_a(n-1)   when (rising_edge(wr_clk) and wr_clk_en='1');
    end generate;
  
--  begin
--    p_in : process(wr_clk)
--    begin
--      if rising_edge(wr_clk) then
--        if wr_rst='1' then
--          ram_addr_a(1 to WR_INPUT_REGS_LOGIC) <= (others=>(others=>'0'));
--          ram_din_a(1 to WR_INPUT_REGS_LOGIC) <= (others=>(others=>'-'));
--          ram_we_a(1 to WR_INPUT_REGS_LOGIC) <= (others=>(others=>'0'));
--        elsif wr_clk_en='1' then
--          for n in 1 to WR_INPUT_REGS_LOGIC loop
--            ram_addr_a(n) <= ram_addr_a(n-1);
--            ram_din_a(n) <= ram_din_a(n-1);
--            ram_we_a(n) <= ram_we_a(n-1);
--          end loop;
--        end if;
--      end if;
--    end process;
  end generate;


--  --! Instantiation of macro xpm_memory_sdpram
--  --! xpm_memory_tdpram: Simple Dual Port RAM
--  --! Xilinx Parameterized Macro, Version 2018.2
--  i_sdp : xpm_memory_sdpram
--  generic map(
--    -- Common module generics
--    MEMORY_SIZE             => WR_DATA_WIDTH * WR_DEPTH,
--    MEMORY_PRIMITIVE        => RAM_TYPE_ULTRASCALE, --string; "auto", "distributed", "block" or "ultra"
--    CLOCKING_MODE           => CLOCKING_MODE, --string; "common_clock", "independent_clock" 
--    ECC_MODE                => "no_ecc", --string; "no_ecc", "encode_only", "decode_only" or "both_encode_and_decode"
--    MEMORY_INIT_FILE        => INIT_FILE_ULTRASCALE, --string; "none" or "<filename>.mem"
--    MEMORY_INIT_PARAM       => "",
--    USE_MEM_INIT            => 1, --integer; 0,1
--    WAKEUP_TIME             => "disable_sleep", --string; "disable_sleep" or "use_sleep_pin"
--    AUTO_SLEEP_TIME         => 0, --Do not Change
--    MESSAGE_CONTROL         => 0,
--    USE_EMBEDDED_CONSTRAINT => 0,
--    MEMORY_OPTIMIZATION     => "true",
--    -- Port A module generics
--    WRITE_DATA_WIDTH_A      => WR_DATA_WIDTH, --positive integer
--    BYTE_WRITE_WIDTH_A      => BYTE_WRITE_WIDTH, --integer; 8, 9, or WRITE_DATA_WIDTH_A value
--    ADDR_WIDTH_A            => 6  , --positive integer
--    -- Port B module generics
--    READ_DATA_WIDTH_B       => RD_DATA_WIDTH, --positive integer
--    ADDR_WIDTH_B            => 6 , --positive integer
--    READ_RESET_VALUE_B      => "0",
--    READ_LATENCY_B          => RAM_INPUT_REGS + RAM_OUTPUT_REGS,
--    WRITE_MODE_B            => WRITE_MODE
--  )
--  port map(
--    -- Common module ports
--    sleep          => '0',
--    -- Port A module ports
--    clka           => wr_clk,
--    ena            => wr_clk_en,
--    wea            => ram_we_a(WR_INPUT_REGS_LOGIC),
--    addra          => ram_addr_a(WR_INPUT_REGS_LOGIC),
--    dina           => ram_din_a(WR_INPUT_REGS_LOGIC),
--    injectsbiterra => '0',
--    injectdbiterra => '0',
--    -- Port B module ports
--    clkb           => rd_clk,
--    rstb           => rd_rst,
--    enb            => rd_clk_en,
--    regceb         => rd_clk_en,
--    addrb          => ram_addr_b(RD_INPUT_REGS_LOGIC),
--    doutb          => ram_dout_b(0),
--    sbiterrb       => open,
--    dbiterrb       => open
--  );

  ram_addr_b(0) <= rd_addr;

  g_rd_addr : if RD_INPUT_REGS_LOGIC>=1 generate
    g_loop : for n in 1 to RD_INPUT_REGS_LOGIC generate
      ram_addr_b(n) <= (others=>'0')   when (rising_edge(rd_clk) and rd_rst='1') else
                       ram_addr_b(n-1) when (rising_edge(rd_clk) and rd_clk_en='1');
    end generate;
--  begin
--    p_addr : process(rd_clk)
--    begin
--      if rising_edge(rd_clk) then
--        if rd_rst='1' then
--          ram_addr_b(1 to RD_INPUT_REGS_LOGIC) <= (others=>(others=>'0'));
--        elsif rd_clk_en='1' then
--          for n in 1 to RD_INPUT_REGS_LOGIC loop
--            ram_addr_b(n) <= ram_addr_b(n-1);
--          end loop;
--        end if;
--      end if;
--    end process;
  end generate;

  g_rd_data : if RD_OUTPUT_REGS_LOGIC>=1 generate
    g_loop : for n in 1 to RD_OUTPUT_REGS_LOGIC generate
      ram_dout_b(n) <= (others=>'-')   when (rising_edge(rd_clk) and rd_rst='1') else
                       ram_dout_b(n-1) when (rising_edge(rd_clk) and rd_clk_en='1');
    end generate;
--  begin
--    p_data : process(rd_clk)
--    begin
--      if rising_edge(rd_clk) then
--        if rd_rst='1' then
--          ram_dout_b(1 to RD_OUTPUT_REGS_LOGIC) <= (others=>(others=>'-'));
--        elsif rd_clk_en='1' then
--          for n in 1 to RD_OUTPUT_REGS_LOGIC loop
--            ram_dout_b(n) <= ram_dout_b(n-1);
--          end loop;
--        end if;
--      end if;
--    end process;
  end generate;

  -- read enable pipeline
  rd_en_q(0) <= rd_en;
  g_rd_data_en : for n in 1 to RD_LATENCY generate
    rd_en_q(n) <= '0' when (rising_edge(rd_clk) and rd_rst='1') else
                  rd_en_q(n-1) when (rising_edge(rd_clk) and rd_clk_en='1');
  end generate;

  rd_data <= ram_dout_b(RD_OUTPUT_REGS_LOGIC);
  rd_data_en <= rd_en_q(RD_LATENCY);

end architecture;
