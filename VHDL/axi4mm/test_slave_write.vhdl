library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simulation test slave for AXI4MM  AW, W and B channel verification.
-- The aw.len must match the W burst length and last flag signaling.
entity test_slave_write is
generic(
  -- Set ALWAYS_READY=false to throttle slave speed with random AWREADY and WREADY signal (back-pressure)
  ALWAYS_READY : boolean := false;
  -- LFSR length of PRBS generator for READY signal generation when ALWAYS_READY=false
  TAPS_RDY     : positive := 19
);
port(
  rst     : in  std_logic;
  clk     : in  std_logic;
  -- write request from master
  aw      : in  work.pkg.axi4_a;
  w       : in  work.pkg.axi4_w;
  awready : out std_logic;
  wready  : out std_logic;
  -- write response towards master
  b       : out work.pkg.axi4_b;
  bready  : in  std_logic
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (2**integer(log2(real(w.data'length)))=w.data'length)
    report test_slave_write'INSTANCE_NAME & " Width of w.data must be a power of 2."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of test_slave_write is

  signal a_transfer, a_pull : std_logic;
  signal a_q_last : std_logic;
  signal a_q : aw'subtype;

  signal w_transfer, w_pull : std_logic;

begin

  a_transfer <= awready and aw.valid;
  a_pull <= not aw_q.valid or (a_q_last and w_transfer);
  w_transfer <= wready and w.valid;

  p_aw: process(clk)
    variable incr : unsigned(7 downto 0); -- address increment
    variable transfer_size_log2 : natural; -- log2 of number of transfers
    variable burst_bytes : natural; -- overall number of valid bytes in the burst
    variable addr_offset4k : natural; -- address offset to 4kB boundary
  begin
    if rising_edge(clk) then
 
      incr := shift_left(to_unsigned(1,incr'length), to_integer(unsigned(a_q.size)));

      if rst='1' then
          a_q.valid <= '0';
      else
        if a_transfer='1' then
          a_q <= aw;
        elsif w_transfer='1' then
          -- next transfer of burst
          if a_q_last='0' then
            a_q.addr <= std_logic_vector(unsigned(a_q.addr) + incr);
            a_q.len  <= std_logic_vector(unsigned(a_q.len) - 1);
          else
            a_q.valid <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  a_q_last <= '1' when unsigned(a_q.len)=0 else '0';

end architecture;
