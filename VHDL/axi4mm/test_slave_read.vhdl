library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Simulation test slave for AXI4MM  AR and R channel verification.
-- r.data returns the related address of the transfer, hence address width should not be larger than the data width.
-- The ar.size information must match the r.data length. The address is incremented accordingly.
-- The ar.len defines the length of the outgoing R channel burst.
entity test_slave_read is
generic(
  -- Address width in data response must be power of 2. Full address is trimmed to this address width.
  R_ADDR_WIDTH : positive := 16;
  -- Set ALWAYS_READY=false to throttle slave speed with random ARREADY signal (back-pressure)
  ALWAYS_READY : boolean := false;
  -- LFSR length of PRBS generator for ARREADY signal generation when ALWAYS_READY=false
  TAPS_RDY     : positive := 19
);
port(
  rst     : in  std_logic;
  clk     : in  std_logic;
  -- read request from master
  ar      : in  work.pkg.axi4_a;
  arready : out std_logic;
  -- read response towards master
  r       : out work.pkg.axi4_r;
  rready  : in  std_logic
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (2**integer(log2(real(r.data'length)))=r.data'length)
    report test_slave_read'INSTANCE_NAME & " Width of r.data must be a power of 2."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of test_slave_read is

  constant R_DATA_BYTES : positive := r.data'length/8;
  constant R_DATA_BYTES_LOG2 : natural := integer(log2(real(R_DATA_BYTES)));

  signal sr_rdy : std_logic_vector(TAPS_RDY downto 1) := (others=>'0');

  signal a_transfer, a_pull : std_logic;
  signal a_q_last : std_logic;
  signal a_q : ar'subtype;

  signal r_transfer, r_pull : std_logic;

begin

  p_rdy: process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        sr_rdy(TAPS_RDY downto 2) <= (others=>'0');
        sr_rdy(1) <= '1';
      elsif arready='0' or a_transfer='1' then
        sr_rdy(TAPS_RDY downto 2) <= sr_rdy(TAPS_RDY-1 downto 1);
        sr_rdy(1) <= sr_rdy(TAPS_RDY) xor sr_rdy(TAPS_RDY-2);
      end if;
    end if;
  end process;

  a_transfer <= arready and ar.valid;
  a_pull <= not a_q.valid or (a_q_last and r_transfer);

--  arready <= '1' when ALWAYS_READY else sr_rdy(TAPS_RDY);
  arready <= a_pull;

  p_ar: process(clk)
    variable incr : unsigned(7 downto 0); -- address increment
    variable transfer_size_log2 : natural; -- log2 of number of transfers
    variable burst_bytes : natural; -- overall number of valid bytes in the burst
    variable addr_offset4k : natural; -- address offset to 4kB boundary
  begin
    if rising_edge(clk) then
      assert (ar.burst="01") or (ar.valid/='1')
      report test_slave_read'INSTANCE_NAME & " Currently only burst type AR.BURST=INCR is supported."
      severity failure;
      assert (unsigned(ar.size)<=R_DATA_BYTES_LOG2) or (ar.valid/='1')
      report test_slave_read'INSTANCE_NAME & " Read request AR.SIZE exeeds R.DATA width and is not AXI standard conform."
      severity failure;
      assert (unsigned(ar.size)=R_DATA_BYTES_LOG2) or (ar.valid/='1')
      report test_slave_read'INSTANCE_NAME & " Read request AR.SIZE is smaller than R.DATA width and not yet supported."
      severity failure;
      assert (unsigned(ar.size)=R_DATA_BYTES_LOG2) or (ar.valid/='1')
      report test_slave_read'INSTANCE_NAME & " Read request AR.SIZE is smaller than R.DATA width and not yet supported."
      severity failure;

      transfer_size_log2 := to_integer(unsigned(ar.size));
      burst_bytes := (to_integer(unsigned(ar.len))+1) * 2**transfer_size_log2;
      addr_offset4k := to_integer(unsigned(ar.addr(11 downto transfer_size_log2))) + burst_bytes;
      assert (burst_bytes<=4096) or (ar.valid/='1')
      report test_slave_read'INSTANCE_NAME & " Requested burst is larger than 4kB and not AXI standard conform."
      severity failure;
      assert (addr_offset4k<=4096) or (ar.valid/='1')
      report test_slave_read'INSTANCE_NAME & " Requested burst crosses 4kB boundary and is not AXI standard conform."
      severity failure;

      -- TODO: check address alignment, ar.size, address output in r.data 

      incr := shift_left(to_unsigned(1,incr'length), to_integer(unsigned(a_q.size)));

      if rst='1' then
          a_q.valid <= '0';
      else
        if a_transfer='1' then
          a_q <= ar;
        elsif r_transfer='1' then
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

  r_pull <= rready; -- temp
  r_transfer <= rready and r.valid;

  r.data  <= std_logic_vector(resize(unsigned(a_q.addr),r.data'length));
  r.last  <= a_q_last;
  r.valid <= a_q.valid;
  r.resp  <= (others=>'0');
  r.user  <= (r.user'length-1 downto 0=>'0'); -- TODO

  assert (r.id'length>=a_q.id'length)
    report "axi4mm.test_slave_read: Response ID must be trimmed to " & integer'image(r.id'length) & " bits."
    severity warning;

  process(a_q.id)
  begin
    if r.id'length<a_q.id'length then
      r.id <= a_q.id(r.id'length-1 downto 0); -- ID trimming
    else
      r.id <= (others=>'0');
      r.id(a_q.id'length-1 downto 0) <= a_q.id; -- ID padding
    end if;
  end process;

end architecture;
