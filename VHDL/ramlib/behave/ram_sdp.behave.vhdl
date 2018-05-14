-------------------------------------------------------------------------------
--! @file       ram_sdp.behave.vhdl
--! @author     Fixitfetish
--! @date       14/May/2016
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

--! @brief Behavioral model of the Simple Dual Port RAM. 

architecture rtl of ram_sdp is

  constant WR_INPUT_REGS : natural := 1;
  constant RD_INPUT_REGS : natural := 1;

  type RAM_type is ARRAY(integer range <>) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
  signal RAM : RAM_type(0 to 2**ADDR_WIDTH-1) := (others => (others => '-'));

  signal wr_addr_en_q : std_logic;
  signal wr_addr_q : unsigned(ADDR_WIDTH-1 downto 0);
  signal wr_data_q : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal rd_addr_en_q : std_logic;
  signal rd_addr_q : unsigned(ADDR_WIDTH-1 downto 0);
  
begin

  p_write : process(clk)
  begin
    if rising_edge(clk) then

      if rst='1' then
        wr_addr_en_q <= '0';
        wr_addr_q <= (others=>'0');
        wr_data_q <= (others=>'0');
      elsif wr_clk_en='1' then
        -- RAM input register
        wr_addr_en_q <= wr_addr_en;
        wr_addr_q <= unsigned(wr_addr);
        wr_data_q <= wr_data;
        
        if wr_addr_en_q='1' then
          RAM(to_integer(wr_addr_q)) <= wr_data_q;
        end if;
      end if;

    end if;
  end process;
    
  p_read_in : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        rd_addr_en_q <= '0';
        rd_addr_q <= (others=>'0');
      elsif rd_clk_en='1' then
        -- RAM input register
        rd_addr_en_q <= rd_addr_en;
        rd_addr_q <= unsigned(rd_addr);
      end if;
    end if;
  end process;

  g_read_out : if RD_OUTPUT_REGS=0 generate 
    rd_data <= RAM(to_integer(rd_addr_q));
    rd_data_en <= rd_addr_en_q; 
  end generate;
  
  g_read_out_reg : if RD_OUTPUT_REGS=1 generate 
  begin
    p_read : process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          rd_data_en <= '0';
          rd_data <= (others=>'-');
        elsif rd_clk_en='1' then
          rd_data_en <= rd_addr_en_q; 
          rd_data <= RAM(to_integer(rd_addr_q));
        end if;
      end if;
    end process;
  end generate;
  
end architecture;
