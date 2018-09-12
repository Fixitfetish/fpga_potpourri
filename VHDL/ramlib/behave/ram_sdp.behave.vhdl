-------------------------------------------------------------------------------
--! @file       ram_sdp.behave.vhdl
--! @author     Fixitfetish
--! @date       12/Sep/2018
--! @version    0.20
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Behavioral model of the Simple Dual Port RAM. 

architecture rtl of ram_sdp is

  type RAM_type is ARRAY(integer range <>) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
  signal RAM : RAM_type(0 to 2**ADDR_WIDTH-1) := (others => (others => '-'));

  type a_wr_addr is array(integer range <>) of unsigned(wr_addr'length-1 downto 0);
  signal wr_addr_q : a_wr_addr(WR_INPUT_REGS downto 1);
  signal wr_en_q : std_logic_vector(WR_INPUT_REGS downto 1);
  
  type a_wr_data is array(integer range <>) of std_logic_vector(wr_data'length-1 downto 0);
  signal wr_data_q : a_wr_data(WR_INPUT_REGS downto 1);

  type a_rd_addr is array(integer range <>) of unsigned(rd_addr'length-1 downto 0);
  signal rd_addr_q : a_rd_addr(RD_INPUT_REGS downto 1);
  signal rd_en_q : std_logic_vector(RD_INPUT_REGS downto 1);
  
  type a_rd_data is array(integer range <>) of std_logic_vector(rd_data'length-1 downto 0);
  signal rd_data_q : a_rd_data(0 to RD_OUTPUT_REGS);
  signal rd_data_en_q : std_logic_vector(0 to RD_OUTPUT_REGS);
  
  
begin

  -- RAM write input register (at least one required)
  p_wr_in : process(wr_clk)
  begin
    if rising_edge(wr_clk) then
      if wr_rst='1' then
        wr_en_q <= (others=>'0');
        wr_addr_q <= (others=>(others=>'0'));
        wr_data_q <= (others=>(others=>'-'));
      elsif wr_clk_en='1' then
        wr_en_q(WR_INPUT_REGS) <= wr_en;
        wr_addr_q(WR_INPUT_REGS) <= unsigned(wr_addr);
        wr_data_q(WR_INPUT_REGS) <= wr_data;
        for n in 1 to (WR_INPUT_REGS-1) loop
          wr_en_q(n) <= wr_en_q(n+1);
          wr_addr_q(n) <= wr_addr_q(n+1);
          wr_data_q(n) <= wr_data_q(n+1);
        end loop;
        RAM(to_integer(wr_addr_q(1))) <= wr_data_q(1);
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
        rd_addr_q(RD_INPUT_REGS) <= unsigned(rd_addr);
        for n in 1 to (RD_INPUT_REGS-1) loop
          rd_addr_q(n) <= rd_addr_q(n+1);
          rd_en_q(n) <= rd_en_q(n+1);
        end loop;
      end if;
    end if;
  end process;

  g_rd_out : if RD_OUTPUT_REGS=0 generate 
    rd_data <= RAM(to_integer(rd_addr_q(1)));
    rd_data_en <= rd_en_q(1); 
  end generate;

  g_rd_out_reg : if RD_OUTPUT_REGS>=1 generate
  begin
    p_read : process(rd_clk)
    begin
      if rising_edge(rd_clk) then
        if rd_rst='1' then
          rd_data_en_q <= (others=>'0');
          rd_data_q <= (others=>(others=>'-'));
        elsif rd_clk_en='1' then
          rd_data_en_q(1) <= rd_en_q(1);
          rd_data_q(1) <= RAM(to_integer(rd_addr_q(1)));
          for n in RD_OUTPUT_REGS downto 2 loop
            rd_data_en_q(n) <= rd_data_en_q(n-1);
            rd_data_q(n) <= rd_data_q(n-1);
          end loop;
        end if;
      end if;
    end process;
    rd_data <= rd_data_q(RD_OUTPUT_REGS);
    rd_data_en <= rd_data_en_q(RD_OUTPUT_REGS);
  end generate;

  
end architecture;
