-------------------------------------------------------------------------------
--! @file       ram_sdp.behave.vhdl
--! @author     Fixitfetish
--! @date       22/Sep/2018
--! @version    0.50
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
  use baselib.ieee_extension.all;

--! @brief Behavioral model of the Simple Dual Port RAM. 

architecture behave of ram_sdp is

  --! byte enable width
  constant WR_BE_WIDTH : positive := WR_DATA_WIDTH/8;
  
  --! write address width
  constant WR_ADDR_WIDTH : positive := log2ceil(WR_DEPTH);

  function DATA_WIDTH_RATIO return positive is
  begin
    if RD_DATA_WIDTH<WR_DATA_WIDTH then
      return WR_DATA_WIDTH/RD_DATA_WIDTH;
    else
      return RD_DATA_WIDTH/WR_DATA_WIDTH;
    end if;
  end function;
  constant DATA_WIDTH_RATIO_LOG2 : positive := log2ceil(DATA_WIDTH_RATIO);

  --! derive read address width from data widths and write address width
  function RD_ADDR_WIDTH return positive is
  begin
    if RD_DATA_WIDTH<WR_DATA_WIDTH then
      return (WR_ADDR_WIDTH + DATA_WIDTH_RATIO_LOG2);
    elsif RD_DATA_WIDTH>WR_DATA_WIDTH then
      return (WR_ADDR_WIDTH - DATA_WIDTH_RATIO_LOG2);
    else
      return WR_ADDR_WIDTH;
    end if;
  end function;

  type t_RAM is ARRAY(integer range <>) of STD_LOGIC_VECTOR(WR_DATA_WIDTH-1 downto 0);
  signal RAM : t_RAM(0 to WR_DEPTH-1) := (others => (others => '0'));
  signal ram_d0, ram_d1 : unsigned(WR_DATA_WIDTH-1 downto 0);

  type a_wr_addr is array(integer range <>) of unsigned(wr_addr'length-1 downto 0);
  signal wr_addr_q : a_wr_addr(WR_INPUT_REGS downto 1);
  signal wr_en_q : std_logic_vector(WR_INPUT_REGS downto 1);
  
  type a_wr_data is array(integer range <>) of std_logic_vector(wr_data'length-1 downto 0);
  signal wr_data_q : a_wr_data(WR_INPUT_REGS downto 1);

  type a_wr_be is array(integer range <>) of std_logic_vector(WR_BE_WIDTH-1 downto 0);
  signal wr_be_q : a_wr_be(WR_INPUT_REGS downto 1);

  type a_rd_addr is array(integer range <>) of unsigned(RD_ADDR_WIDTH-1 downto 0);
  signal rd_addr_q : a_rd_addr(RD_INPUT_REGS downto 1);
  signal rd_en_q : std_logic_vector(RD_INPUT_REGS downto 1);
  
  type a_rd_data is array(integer range <>) of std_logic_vector(RD_DATA_WIDTH-1 downto 0);
  signal rd_data_q : a_rd_data(0 to RD_OUTPUT_REGS);
  signal rd_data_en_q : std_logic_vector(0 to RD_OUTPUT_REGS);
  
  
begin

  -- RAM write input register (at least one required)
  p_wr_in : process(wr_clk)
    -- data bit mask according to byte enables
    variable v_mask : std_logic_vector(WR_DATA_WIDTH-1 downto 0);
  begin
    if rising_edge(wr_clk) then
      if wr_rst='1' then
        wr_en_q <= (others=>'0');
        wr_addr_q <= (others=>(others=>'0'));
        wr_data_q <= (others=>(others=>'-'));
        wr_be_q <= (others=>(others=>'0'));
      elsif wr_clk_en='1' then
        wr_en_q(WR_INPUT_REGS) <= wr_en;
        wr_addr_q(WR_INPUT_REGS) <= resize(unsigned(wr_addr),WR_ADDR_WIDTH);
        wr_data_q(WR_INPUT_REGS) <= wr_data;
        -- byte enables
        if WR_USE_BYTE_ENABLE then
          wr_be_q(WR_INPUT_REGS) <= wr_be;
        else
          wr_be_q(WR_INPUT_REGS) <= (others=>'1');
        end if;
        -- input register pipeline
        for n in 1 to (WR_INPUT_REGS-1) loop
          wr_en_q(n) <= wr_en_q(n+1);
          wr_addr_q(n) <= wr_addr_q(n+1);
          wr_data_q(n) <= wr_data_q(n+1);
          wr_be_q(n) <= wr_be_q(n+1);
        end loop;
        -- byte enable mask
        for i in 0 to WR_BE_WIDTH-1 loop
          if wr_be_q(1)(i)='1' then
            v_mask((i+1)*8-1 downto i*8) := x"FF"; 
          else
            v_mask((i+1)*8-1 downto i*8) := x"00"; 
          end if;
        end loop;
        -- RAM access
        if wr_en_q(1)='1' then
          RAM(to_integer(wr_addr_q(1))) <=
            (wr_data_q(1) and v_mask)  or  (RAM(to_integer(wr_addr_q(1))) and (not v_mask));
        end if;
      end if;
    end if;
  end process;

 
  -- RAM read input register (at least one required)
  p_rd_in : process(rd_clk)
  begin
    if rising_edge(rd_clk) then
      if rd_rst='1' then
        rd_en_q <= (others=>'0');
        rd_addr_q <= (others=>(others=>'0'));
      elsif rd_clk_en='1' then
        rd_en_q(RD_INPUT_REGS) <= rd_en;
        rd_addr_q(RD_INPUT_REGS) <= resize(unsigned(rd_addr),RD_ADDR_WIDTH);
        for n in 1 to (RD_INPUT_REGS-1) loop
          rd_addr_q(n) <= rd_addr_q(n+1);
          rd_en_q(n) <= rd_en_q(n+1);
        end loop;
      end if;
    end if;
  end process;

  g_rd_equal : if WR_DATA_WIDTH=RD_DATA_WIDTH generate
    rd_data_q(0) <= RAM(to_integer(rd_addr_q(1)));
  end generate;

  g_rd_less : if WR_DATA_WIDTH>RD_DATA_WIDTH generate
    ram_d0 <= unsigned(RAM(to_integer(rd_addr_q(1)(rd_addr_q(1)'high downto DATA_WIDTH_RATIO_LOG2))));
    ram_d1 <= shift_right(ram_d0,RD_DATA_WIDTH*to_integer(rd_addr_q(1)(DATA_WIDTH_RATIO_LOG2-1 downto 0)));
    rd_data_q(0) <= std_logic_vector(ram_d1(RD_DATA_WIDTH-1 downto 0));
  end generate;

  g_rd_more : if WR_DATA_WIDTH<RD_DATA_WIDTH generate
    gloop : for n in 0 to DATA_WIDTH_RATIO-1 generate
      rd_data_q(0)((n+1)*WR_DATA_WIDTH-1 downto n*WR_DATA_WIDTH) <= RAM(DATA_WIDTH_RATIO*to_integer(rd_addr_q(1))+n);
    end generate;
  end generate;

  rd_data_en_q(0) <= rd_en_q(1);

  g_rd_out_reg : for n in 1 to RD_OUTPUT_REGS generate
  begin
    process(rd_clk)
    begin
      if rising_edge(rd_clk) then
        if rd_rst='1' then
          rd_data_en_q(n) <= '0';
          rd_data_q(n) <= (others=>'-');
        elsif rd_clk_en='1' then
          rd_data_en_q(n) <= rd_data_en_q(n-1);
          rd_data_q(n) <= rd_data_q(n-1);
        end if;
      end if;
    end process;
  end generate;

  rd_data <= rd_data_q(RD_OUTPUT_REGS);
  rd_data_en <= rd_data_en_q(RD_OUTPUT_REGS);
  
end architecture;
