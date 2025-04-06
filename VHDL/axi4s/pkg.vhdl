-------------------------------------------------------------------------------
--! @file       pkg.vhdl
--! @note       VHDL2008
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief AXI4 Streaming interface package
--! * defines partly unconstrained AXI4 base types
--! * see also AMBA AXI-Stream Protocol Specification:  https://developer.arm.com/documentation/ihi0051/a
package pkg is

  --! unconstrained AXI4 streaming channel for any data width (source is the AXI master)
  type axi4s is record
    -- TDATA is the primary payload that is used to provide the data that is passing across
    -- the interface. The width of the data payload is an integer number of bytes, i.e. a multiple of 8 bits.
    tdata  : std_logic_vector;
    -- TDEST provides routing information for the data stream.
    -- Recommended maximum width is 4 bits.
    tdest  : std_logic_vector;
    -- TID is the data stream identifier that indicates different streams of data.
    -- Recommended maximum width is 8 bits.
    tid    : std_logic_vector;
    -- TKEEP is the byte qualifier that indicates whether the content of the associated
    -- byte of TDATA is processed as part of the data stream. Associated bytes that have the TKEEP
    -- byte qualifier deasserted are null bytes and can be removed from the data stream.
    -- Width must be TDATA_WIDTH/8 .
    tkeep  : std_logic_vector;
    -- TLAST indicates the boundary of a packet and is useful to control arbitration and flushing.
    tlast  : std_logic;
    -- TSTRB is the byte qualifier that indicates whether the content of the associated byte
    -- of TDATA is processed as a data byte or a position byte. Width must be TDATA_WIDTH/8 .
    tstrb  : std_logic_vector;
    -- TUSER defined sideband information that can be transmitted alongside the data stream.
    -- Recommended number of bits is an integer multiple of the width of the interface in bytes.
    -- Hence, width should be M*(TDATA_WIDTH/8), i.e. M bits per data byte.
    tuser  : std_logic_vector;
    -- TVALID indicates that the master is driving a valid transfer. A transfer takes place
    -- when both TVALID and TREADY are asserted.
    tvalid : std_logic;
  end record;

  --! General unconstrained AXI4 streaming vector type (preferably "to" direction)
  type a_axi4s is array (integer range <>) of axi4s;

  ----------
  -- RESETS
  ----------

  -- Reset AXI4 streaming channel
  function reset(s: axi4s) return axi4s;

  -- Reset AXI4 streaming vector
  function reset(s: a_axi4s) return a_axi4s;

  -- Constant reset value of streaming channel with specific width of elements
  function reset_axi4s(
    constant TDATA_WIDTH : positive;
    constant TDEST_WIDTH : positive;
    constant TID_WIDTH   : positive;
    constant TUSER_WIDTH : positive
  ) return axi4s;

  ------------------
  -- CONVERSION
  ------------------

  -- number of overall bits in the AXI4 stream record, including the valid (but without the ready)
  function length(s: axi4s) return positive;

  -- concatenate all AXI4 streaming channel record elements into a SLV
  function to_slv(s: axi4s) return std_logic_vector;

  -- split a SLV into AXI4 streaming channel record elements
  function to_record(slv: std_logic_vector; s: axi4s) return axi4s;

  -- Pad or trim TID or TDEST signal.
  function dest_id_resize(
    din             : std_logic_vector; -- input ID or DEST
    constant OUTLEN : positive -- Required output length
  ) return std_logic_vector;

  -- Pad or trim USER signal.
  -- Set the argument BYTES=1 if the user signal is not defined per data bytes but per transfer.
  function user_resize(
    -- User signal source input. Length must be a multiple of argument BYTES, i.e. this signal is
    -- expected to have (USER'length/BYTES) bits per data byte.
    user            : std_logic_vector;
    -- Required output length must be a multiple of argument BYTES.
    constant OUTLEN : positive;
    -- Number of data bytes to which the input USER corresponds
    constant BYTES  : positive := 1
  ) return std_logic_vector;

  -- Stream bypass with interface adjustments -> padding, trimming and some error checks
  procedure bypass(
    variable s_stream : in  axi4s; -- input from master
    variable m_stream : out axi4s; -- output towards slave
    constant USER_BYTEWISE : boolean := true; -- TUSER bits per byte (set false when bits are per transfer)
    constant USER_IGNORE : boolean := false -- discard TUSER bits and force output TUSER bits to zero 
  );

end package;

-----------------------------------------------------------------------------------------------------------------------

package body pkg is

  ----------
  -- RESETS
  ----------

  function reset(s: axi4s) return axi4s is
    variable rst : s'subtype;
  begin
    rst.tdata  := (rst.tdata'range => '-');
    rst.tdest  := (rst.tdest'range => '-');
    rst.tid    := (rst.tid'range => '-');
    rst.tkeep  := (rst.tkeep'range => '-');
    rst.tlast  := '-';
    rst.tstrb  := (rst.tstrb'range => '-');
    rst.tuser  := (rst.tuser'range => '-');
    rst.tvalid := '0';
    return rst;
  end function;

  function reset(s: a_axi4s) return a_axi4s is
    variable rst : s'subtype;
  begin
    rst := (others => reset(s(s'low)));
    return rst;
  end function;

  function reset_axi4s(
    constant TDATA_WIDTH : positive;
    constant TDEST_WIDTH : positive;
    constant TID_WIDTH   : positive;
    constant TUSER_WIDTH : positive
  ) return axi4s is
    variable rst : axi4s(
      tdata(TDATA_WIDTH - 1 downto 0),
      tdest(TDEST_WIDTH - 1 downto 0),
      tid(TID_WIDTH - 1 downto 0),
      tkeep(TDATA_WIDTH / 8 - 1 downto 0),
      tstrb(TDATA_WIDTH / 8 - 1 downto 0),
      tuser(TUSER_WIDTH - 1 downto 0)
    );
  begin
    rst := reset(rst);
    return rst;
  end function;

  ------------------
  -- CONVERSION
  ------------------

  function rev_range(slv : in std_logic_vector)
  return std_logic_vector is
    alias result : std_logic_vector(slv'reverse_range) is slv;
  begin
    return result;
  end;

  function slice_slv(
    src    : std_logic_vector;
    dest   : std_logic_vector;
    offset : integer
  )
  return std_logic_vector is
    variable ret : dest'subtype;
  begin
    assert src'ascending report "only supported for to range in src" severity error;
    if ret'ascending then
      ret := src(src'left + offset to src'left + offset + ret'length - 1);
    else
      ret := rev_range(src(src'left + offset to src'left + offset + ret'length - 1));
    end if;
    return ret;
  end function;

  -- number of overall bits in the AXI4 stream record, including the valid
  function length(s: axi4s) return positive is
  begin
    -- plus 2 for valid and last
    return (2 + s.tdata'length + s.tstrb'length + s.tkeep'length + s.tid'length + s.tdest'length + s.tuser'length);
  end function;

  -- concatenate all AXI4 streaming channel record elements into a SLV
  function to_slv(s: axi4s) return std_logic_vector is
    constant slv : std_logic_vector := s.tvalid & s.tlast & s.tdata & s.tstrb & s.tkeep & s.tid & s.tdest & s.tuser;
  begin
    return slv;
  end function;

  -- split a SLV into AXI4 streaming channel record elements
  function to_record(
    slv : std_logic_vector; -- input SLV
    s   : axi4s -- target stream
  )
  return axi4s is
    variable r         : s'subtype;
    constant valid_idx : integer := 0;
    constant last_idx  : integer := valid_idx + 1;
    constant data_idx  : integer := last_idx + 1;
    constant strb_idx  : integer := data_idx + r.tdata'length;
    constant keep_idx  : integer := strb_idx + r.tstrb'length;
    constant id_idx    : integer := keep_idx + r.tkeep'length;
    constant dest_idx  : integer := id_idx   + r.tid'length;
    constant user_idx  : integer := dest_idx + r.tdest'length;
  begin
    r.tvalid := slv(valid_idx);
    r.tlast  := slv(last_idx);
    r.tdata  := slice_slv(slv, r.tdata, data_idx);
    r.tstrb  := slice_slv(slv, r.tstrb, strb_idx);
    r.tkeep  := slice_slv(slv, r.tkeep, keep_idx);
    r.tid    := slice_slv(slv, r.tid  , id_idx  );
    r.tdest  := slice_slv(slv, r.tdest, dest_idx);
    r.tuser  := slice_slv(slv, r.tuser, user_idx);
    return r;
  end function;

  function dest_id_resize(
    din             : std_logic_vector; -- input TID or TDEST
    constant OUTLEN : positive -- Required output length
  ) return std_logic_vector is
    alias xdin : std_logic_vector(din'length-1 downto 0) is din; -- default range
    variable r : std_logic_vector(OUTLEN-1 downto 0);
  begin
    r := std_logic_vector(resize(unsigned(xdin),OUTLEN));
    assert (OUTLEN >= din'length)
      report "axi4s.pkg.id_dest_resize(): Some bits have been trimmed/discarded because TID or TDEST width of master and slave do not match."
      severity warning;
    return r;
  end function;

  -- Pad or trim USER signal.
  -- Set the argument BYTES=1 if the user signal is not defined per data bytes but per transfer.
  function user_resize(
    -- User signal source input. Length must be a multiple of argument BYTES, i.e. this signal is
    -- expected to have (USER'length/BYTES) bits per data byte.
    user            : std_logic_vector;
    -- Required output length must be a multiple of argument BYTES.
    constant OUTLEN : positive;
    -- Number of data bytes to which the input USER corresponds
    constant BYTES  : positive := 1
  ) return std_logic_vector is
    constant INLEN : positive := user'length;
    alias xuser : std_logic_vector(INLEN-1 downto 0) is user; -- default range
    constant INBITS : positive := INLEN / BYTES; -- input bits per data byte
    constant OUTBITS : positive := OUTLEN / BYTES; -- output bits per data byte
    constant BITS : positive := minimum(INBITS,OUTBITS); -- relevant bits per data byte
    variable r : std_logic_vector(OUTLEN-1 downto 0);
  begin
    r := (others=>'0'); -- default output
    if BYTES=1 then
      r(BITS-1 downto 0) := xuser(BITS-1 downto 0);
    else
      assert (INLEN mod BYTES = 0) and (OUTLEN mod BYTES = 0)
        report "axi4s.pkg.user_resize(): Input or output length is not a multiple of argument BYTES."
        severity failure;
      for b in 0 to BYTES-1 loop
        r(b*OUTBITS+BITS-1 downto b*OUTBITS) := xuser(b*INBITS+BITS-1 downto b*INBITS);
      end loop;
    end if;
    assert (OUTBITS >= INBITS)
      report "axi4s.pkg.user_resize(): Some user bits have been trimmed/discarded because the number of output bits is less than the number of input bits."
      severity warning;
    return r;
  end function;

  procedure bypass(
    variable s_stream : in  axi4s;
    variable m_stream : out axi4s;
    constant USER_BYTEWISE : boolean := true;
    constant USER_IGNORE : boolean := false
  ) is
  begin
    assert (s_stream.tdata'length = m_stream.tdata'length)
      report "axi4s.pkg.bypass(): master and slave interface must have same TDATA width."
      severity failure;
    assert (s_stream.tstrb'length = m_stream.tstrb'length) and (s_stream.tkeep'length = m_stream.tkeep'length)
      report "axi4s.pkg.bypass(): master and slave interface must have same TSTRB and TKEEP width."
      severity failure;
    m_stream.tdest  := dest_id_resize(s_stream.tdest, m_stream.tdest'length);
    m_stream.tid    := dest_id_resize(s_stream.tid, m_stream.tid'length);
    m_stream.tdata  := s_stream.tdata;
    m_stream.tstrb  := s_stream.tstrb;
    m_stream.tkeep  := s_stream.tkeep;
    m_stream.tlast  := s_stream.tlast;
    m_stream.tvalid := s_stream.tvalid;
    if USER_IGNORE then
      m_stream.tuser := std_logic_vector(to_unsigned(0,m_stream.tuser'length));
    elsif USER_BYTEWISE then
      m_stream.tuser := user_resize(user=>s_stream.tuser, OUTLEN=>m_stream.tuser'length, BYTES=>s_stream.tstrb'length);
    else
      m_stream.tuser := user_resize(user=>s_stream.tuser, OUTLEN=>m_stream.tuser'length, BYTES=>1);
    end if;
  end procedure;

end package body;
