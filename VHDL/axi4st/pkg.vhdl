-------------------------------------------------------------------------------
-- @file       pkg.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- AXI4 Streaming interface package
-- * defines partly unconstrained AXI4 base types
-- * see also AMBA AXI-Stream Protocol Specification:  https://developer.arm.com/documentation/ihi0051/a
--
-- **Extensions to the AXI4-Stream standard**
-- * According to the AXI4-Streaming specification an item is 8 bits (1 byte) wide.
--   However, this library allows any item width. Each TSTRB/TKEEP bit corresponds to one item.
-- * The AXI4-Streaming specification defines/recommends a 2^n number of items (bytes) in TDATA.
--   However, this library allows any positive integer number of items in TDATA.
-- * The AXI4-Streaming standard only specifies the global active-low reset ARESETN which can cause timing
--   issues. This library supports an additional transmitter driven pipelined active-high reset signal.
--
package pkg is

  -- unconstrained AXI4 streaming channel for any data width (source is the AXI master/transmitter)
  type axi4_s is record
    -- TDATA is the primary payload that is used to provide the data that is passing across
    -- the interface. According to the AXI4 standard the width of the data payload is an integer
    -- number of bytes, i.e. a multiple of 8 bits (but also other item sizes are possible here).
    tdata  : std_logic_vector;
    -- TDEST provides routing information for the data stream.
    -- Recommended maximum width is 4 bits.
    tdest  : std_logic_vector;
    -- TID is the data stream identifier that indicates different streams of data.
    -- Recommended maximum width is 8 bits.
    tid    : std_logic_vector;
    -- TKEEP is the item (byte) qualifier that indicates whether the content of the associated
    -- item (byte) of TDATA is processed as part of the data stream. Associated items (bytes)
    -- that have the TKEEP item (byte) qualifier deasserted are null items (bytes) and can be
    -- removed from the data stream. Width must match the number of items (bytes) in TDATA.
    tkeep  : std_logic_vector;
    -- TLAST indicates the boundary of a packet and is useful to control arbitration and flushing.
    tlast  : std_logic;
    -- TSTRB is the item (byte) qualifier that indicates whether the content of the associated
    -- item (byte) of TDATA is processed as a data item (byte) or a position item (byte).
    -- Width must match the number of items (bytes) in TDATA.
    tstrb  : std_logic_vector;
    -- TUSER defined sideband information that can be transmitted alongside the data stream.
    -- Recommended number of bits is an integer multiple of the width of TSTRB or TKEEP.
    -- Hence, width should be M*TSTRB_WIDTH, i.e. M bits per data item (byte).
    tuser  : std_logic_vector;
    -- TVALID indicates that the master/transmitter is driving a valid transfer.
    -- A transfer takes place when both TVALID and TREADY are asserted.
    tvalid : std_logic;
    -- TRESET is a transmitter driven active-high pipelined reset that can replace the global
    -- ARESETN and therefore avoid ARESETN related timing issues.
    -- (proprietary extension to the AXI4-Streaming standard)
    treset : std_logic;
  end record;

  -- General unconstrained AXI4 streaming vector type (preferably "to" direction)
  type a_axi4_s is array (integer range <>) of axi4_s;

  type t_pipestage is (
    -- No pipestage or logic inserted in bypass mode
    bypass,
    -- No pipestage but just decoupling logic is inserted: tvalid=0 and tready=1 during reset
    decouple,
    -- upstream tdata and tvalid is registered with downstream tready as clock_enable 
    simple,
    -- upstream tdata and tvalid is registered with downstream (tready or not tvalid)
    priming,
    -- like simple, but upstream tdata is only registered when upstream tvalid=1 (reduce toggling, save power)
    gating,
    -- like priming, but tdata is only registered when upstream tvalid=1 (reduce toggling, save power)
    primegating,
    -- break up the ready path to improve timing, a bit more complex logic
    ready_breakup
  );
  type a_pipestage is array (natural range <>) of t_pipestage;

  ---------------------
  -- Default and Reset
  ---------------------

  -- Invalid AXI4 streaming channel
  function invalid(s: axi4_s) return axi4_s;

  -- Invalid AXI4 streaming vector
  function invalid(s: a_axi4_s) return a_axi4_s;

  -- Reset AXI4 streaming channel
  function reset(s: axi4_s) return axi4_s;

  -- Reset AXI4 streaming vector
  function reset(s: a_axi4_s) return a_axi4_s;

  -- Constant reset value of streaming channel with specific width of record elements
  function reset_axi4_s(
    constant TDATA_WIDTH : positive;
    constant TDEST_WIDTH : positive;
    constant TID_WIDTH   : positive;
    constant TUSER_WIDTH : positive;
    constant ITEM_WIDTH  : positive := 8 -- AXI4 standard requires an item size of 8 bits (1 byte)
  ) return axi4_s;

  ------------------
  -- CONVERSION
  ------------------

  -- number of overall bits in the AXI4 stream record, including the valid (but without the ready)
  function length(s: axi4_s) return positive;

  -- concatenate all AXI4 streaming channel record elements into a SLV
  function to_slv(s: axi4_s) return std_logic_vector;

  -- split a SLV into AXI4 streaming channel record elements
  function to_record(slv: std_logic_vector; s: axi4_s) return axi4_s;

  -- Pad or trim TID or TDEST signal.
  function dest_id_resize(
    din             : std_logic_vector; -- input ID or DEST
    constant OUTLEN : positive -- Required output length
  ) return std_logic_vector;

  -- Pad or trim USER signal.
  -- Set the argument ITEMS=1 if the user signal is not defined per data item (byte) but per transfer.
  function user_resize(
    -- User signal source input. Length must be a multiple of argument ITEMS, i.e. this signal is
    -- expected to have (USER'length/ITEMS) bits per data item (byte).
    user            : std_logic_vector;
    -- Required output length must be a multiple of argument ITEMS.
    constant OUTLEN : positive;
    -- Number of data items (bytes) to which the input USER corresponds
    constant ITEMS  : positive := 1
  ) return std_logic_vector;

  -- Stream bypass with interface adjustments -> padding, trimming and some error checks
  procedure bypass(
    s_stream : in  axi4_s; -- input from master (variable or signal)
    variable m_stream : out axi4_s; -- output towards slave (variable!)
    constant TDATA_TRIM : boolean := false; -- set TVALID='0' if all TKEEP bits are '0'
    constant TDEST_IGNORE : boolean := false; -- discard TDEST bits and force output TDEST bits to zero 
    constant TID_IGNORE : boolean := false; -- discard TID bits and force output TID bits to zero 
    constant TUSER_IGNORE : boolean := false; -- discard TUSER bits and force output TUSER bits to zero 
    constant TUSER_ITEMWISE : boolean := true -- TUSER bits per item (set false when bits are per transfer)
  );

end package;

-----------------------------------------------------------------------------------------------------------------------

package body pkg is

  ---------------------
  -- Default and Reset
  ---------------------

  function invalid(s: axi4_s) return axi4_s is
    variable r : s'subtype;
  begin
    r.tdata  := (r.tdata'range => '-');
    r.tdest  := (r.tdest'range => '-');
    r.tid    := (r.tid'range => '-');
    r.tkeep  := (r.tkeep'range => '-');
    r.tlast  := '-';
    r.tstrb  := (r.tstrb'range => '-');
    r.tuser  := (r.tuser'range => '-');
    r.tvalid := '0';
    r.treset := '0';
    return r;
  end function;

  function invalid(s: a_axi4_s) return a_axi4_s is
    variable r : s'subtype;
  begin
    r := (others => reset(s(s'low)));
    return r;
  end function;

  function reset(s: axi4_s) return axi4_s is
    variable r : s'subtype;
  begin
    r.tdata  := (r.tdata'range => '-');
    r.tdest  := (r.tdest'range => '-');
    r.tid    := (r.tid'range => '-');
    r.tkeep  := (r.tkeep'range => '-');
    r.tlast  := '-';
    r.tstrb  := (r.tstrb'range => '-');
    r.tuser  := (r.tuser'range => '-');
    r.tvalid := '0';
    r.treset := '1';
    return r;
  end function;

  function reset(s: a_axi4_s) return a_axi4_s is
    variable r : s'subtype;
  begin
    r := (others => reset(s(s'low)));
    return r;
  end function;

  function reset_axi4_s(
    constant TDATA_WIDTH : positive;
    constant TDEST_WIDTH : positive;
    constant TID_WIDTH   : positive;
    constant TUSER_WIDTH : positive;
    constant ITEM_WIDTH  : positive := 8
  ) return axi4_s is
    variable r : axi4_s(
      tdata(TDATA_WIDTH - 1 downto 0),
      tdest(TDEST_WIDTH - 1 downto 0),
      tid(TID_WIDTH - 1 downto 0),
      tkeep(TDATA_WIDTH / ITEM_WIDTH - 1 downto 0),
      tstrb(TDATA_WIDTH / ITEM_WIDTH - 1 downto 0),
      tuser(TUSER_WIDTH - 1 downto 0)
    );
  begin
    r := reset(r);
    return r;
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
  function length(s: axi4_s) return positive is
  begin
    -- plus 3 for tvalid, tlast and treset
    return (3 + s.tdata'length + s.tstrb'length + s.tkeep'length + s.tid'length + s.tdest'length + s.tuser'length);
  end function;

  -- concatenate all AXI4 streaming channel record elements into a SLV
  function to_slv(s: axi4_s) return std_logic_vector is
    constant slv : std_logic_vector := s.tvalid & s.tlast & s.treset & s.tdata & s.tstrb & s.tkeep & s.tid & s.tdest & s.tuser;
  begin
    return slv;
  end function;

  -- split a SLV into AXI4 streaming channel record elements
  function to_record(
    slv : std_logic_vector; -- input SLV
    s   : axi4_s -- target stream
  )
  return axi4_s is
    variable r         : s'subtype;
    constant valid_idx : integer := 0;
    constant last_idx  : integer := valid_idx + 1;
    constant reset_idx : integer := last_idx + 1;
    constant data_idx  : integer := reset_idx + 1;
    constant strb_idx  : integer := data_idx + r.tdata'length;
    constant keep_idx  : integer := strb_idx + r.tstrb'length;
    constant id_idx    : integer := keep_idx + r.tkeep'length;
    constant dest_idx  : integer := id_idx   + r.tid'length;
    constant user_idx  : integer := dest_idx + r.tdest'length;
  begin
    r.tvalid := slv(valid_idx);
    r.tlast  := slv(last_idx);
    r.treset := slv(reset_idx);
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
      report "axi4st.pkg.id_dest_resize(): Some bits have been trimmed/discarded because TID or TDEST width of master and slave do not match."
      severity warning;
    return r;
  end function;

  -- Pad or trim USER signal.
  -- Set the argument ITEMS=1 if the user signal is not defined per data item (byte) but per transfer.
  function user_resize(
    -- User signal source input. Length must be a multiple of argument ITEMS, i.e. this signal is
    -- expected to have (USER'length/ITEMS) bits per data item (byte).
    user            : std_logic_vector;
    -- Required output length must be a multiple of argument ITEMS.
    constant OUTLEN : positive;
    -- Number of data items (bytes) to which the input USER corresponds
    constant ITEMS  : positive := 1
  ) return std_logic_vector is
    constant INLEN : positive := user'length;
    alias xuser : std_logic_vector(INLEN-1 downto 0) is user; -- default range
    constant INBITS : positive := INLEN / ITEMS; -- input bits per data item/byte
    constant OUTBITS : positive := OUTLEN / ITEMS; -- output bits per data item/byte
    constant BITS : positive := minimum(INBITS,OUTBITS); -- relevant bits per data item/byte
    variable r : std_logic_vector(OUTLEN-1 downto 0);
  begin
    r := (others=>'0'); -- default output
    if ITEMS=1 then
      r(BITS-1 downto 0) := xuser(BITS-1 downto 0);
    else
      assert (INLEN mod ITEMS = 0) and (OUTLEN mod ITEMS = 0)
        report "axi4st.pkg.user_resize(): Input or output length is not a multiple of argument ITEMS."
        severity failure;
      for b in 0 to ITEMS-1 loop
        r(b*OUTBITS+BITS-1 downto b*OUTBITS) := xuser(b*INBITS+BITS-1 downto b*INBITS);
      end loop;
    end if;
    assert (OUTBITS >= INBITS)
      report "axi4st.pkg.user_resize(): Some user bits have been trimmed/discarded because the number of output bits is less than the number of input bits."
      severity warning;
    return r;
  end function;

  procedure bypass(
    s_stream : in  axi4_s;
    variable m_stream : out axi4_s;
    constant TDATA_TRIM : boolean := false;
    constant TDEST_IGNORE : boolean := false;
    constant TID_IGNORE : boolean := false;
    constant TUSER_IGNORE : boolean := false;
    constant TUSER_ITEMWISE : boolean := true
  ) is
  begin
    assert (s_stream.tdata'length = m_stream.tdata'length)
      report "axi4st.pkg.bypass(): master and slave interface must have same TDATA width."
      severity failure;
    assert (s_stream.tstrb'length = m_stream.tstrb'length) and (s_stream.tkeep'length = m_stream.tkeep'length)
      report "axi4st.pkg.bypass(): master and slave interface must have same TSTRB and TKEEP width."
      severity failure;
    m_stream.tdata  := s_stream.tdata;
    m_stream.tstrb  := s_stream.tstrb;
    m_stream.tkeep  := s_stream.tkeep;
    m_stream.tlast  := s_stream.tlast;
    m_stream.treset := s_stream.treset;
    if TDEST_IGNORE then
      m_stream.tdest := (m_stream.tdest'range=>'0');
    else
      m_stream.tdest := dest_id_resize(s_stream.tdest, m_stream.tdest'length);
    end if;
    if TID_IGNORE then
      m_stream.tid := (m_stream.tid'range=>'0');
    else
      m_stream.tid := dest_id_resize(s_stream.tid, m_stream.tid'length);
    end if;
    if TDATA_TRIM and s_stream.tkeep=(s_stream.tkeep'range=>'0') then
      m_stream.tvalid := '0';
    else
    m_stream.tvalid := s_stream.tvalid;
    end if;
    if TUSER_IGNORE then
      m_stream.tuser := std_logic_vector(to_unsigned(0,m_stream.tuser'length));
    elsif TUSER_ITEMWISE then
      m_stream.tuser := user_resize(user=>s_stream.tuser, OUTLEN=>m_stream.tuser'length, ITEMS=>s_stream.tstrb'length);
    else
      m_stream.tuser := user_resize(user=>s_stream.tuser, OUTLEN=>m_stream.tuser'length, ITEMS=>1);
    end if;
  end procedure;

end package body;
