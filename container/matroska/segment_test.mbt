///|
fn segment_bytes(payload : Array[Byte]) -> Bytes {
  let bytes : Array[Byte] = Array::new(capacity=payload.length() + 5)
  bytes.push(0x18)
  bytes.push(0x53)
  bytes.push(0x80)
  bytes.push(0x67)
  bytes.push((0x80 + payload.length()).to_byte())
  for byte in payload {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn segment_child(id : Array[Byte], payload : Array[Byte]) -> Array[Byte] {
  let bytes : Array[Byte] = Array::new(
    capacity=id.length() + payload.length() + 1,
  )
  for byte in id {
    bytes.push(byte)
  }
  bytes.push((0x80 + payload.length()).to_byte())
  for byte in payload {
    bytes.push(byte)
  }
  bytes
}

///|
fn segment_info_payload() -> Array[Byte] {
  let payload = Array::new(capacity=32)
  payload.append(segment_child([0x2a, 0xd7, 0xb1], [0x0f, 0x42, 0x40]))
  payload.append(segment_child([0x4d, 0x80], [0x6d]))
  payload.append(segment_child([0x57, 0x41], [0x77]))
  payload
}

///|
fn segment_track_entry(codec : Array[Byte]) -> Array[Byte] {
  let payload = Array::new(capacity=16)
  payload.append(segment_child([0xd7], [0x01]))
  payload.append(segment_child([0x73, 0xc5], [0x01]))
  payload.append(segment_child([0x83], [0x01]))
  payload.append(segment_child([0x86], codec))
  segment_child([0xae], payload)
}

///|
fn parse_segment_fixture(
  payload : Array[Byte],
) -> Result[SegmentMetadata, SegmentError] {
  let bytes = segment_bytes(payload)
  match @ebml.read_element(bytes[:]) {
    Ok(element) => parse_segment(element)
    Err(error) => Err(Walk(@ebml.Element(0, error)))
  }
}

///|
test "parse Segment Info and Tracks together" {
  let payload = Array::new(capacity=64)
  payload.append(
    segment_child([0x15, 0x49, 0xa9, 0x66], segment_info_payload()),
  )
  let tracks_payload = Array::new(capacity=24)
  tracks_payload.append(segment_track_entry([0x56, 0x5f, 0x56, 0x50, 0x38]))
  payload.append(segment_child([0x16, 0x54, 0xae, 0x6b], tracks_payload))
  payload.append(segment_child([0x1f, 0x43, 0xb6, 0x75], [0x80]))
  match parse_segment_fixture(payload) {
    Ok(segment) => {
      assert_eq(segment.info.timecode_scale, 1000000UL)
      assert_eq(segment.info.muxing_app, "m")
      assert_eq(segment.tracks.entries.length(), 1)
      assert_eq(segment.tracks.entries[0].codec_id, "V_VP8")
    }
    Err(_) => fail("expected a complete Segment summary")
  }
}

///|
test "report missing required Segment masters" {
  match parse_segment_fixture([]) {
    Err(MissingRequired(id)) => assert_eq(id, 0x1549a966UL)
    _ => fail("expected missing Info to be reported first")
  }
  let info_only = segment_child(
    [0x15, 0x49, 0xa9, 0x66],
    segment_info_payload(),
  )
  match parse_segment_fixture(info_only) {
    Err(MissingRequired(id)) => assert_eq(id, 0x1654ae6bUL)
    _ => fail("expected missing Tracks to be reported")
  }
}

///|
test "reject duplicate Segment masters" {
  let payload = Array::new(capacity=64)
  payload.append(
    segment_child([0x15, 0x49, 0xa9, 0x66], segment_info_payload()),
  )
  payload.append(
    segment_child([0x15, 0x49, 0xa9, 0x66], segment_info_payload()),
  )
  match parse_segment_fixture(payload) {
    Err(DuplicateElement(id)) => assert_eq(id, 0x1549a966UL)
    _ => fail("expected duplicate Info detection")
  }
}

///|
test "preserve nested TrackEntry errors with offsets" {
  let payload = Array::new(capacity=64)
  payload.append(
    segment_child([0x15, 0x49, 0xa9, 0x66], segment_info_payload()),
  )
  let tracks_payload = segment_child([0xae], [0xd7, 0x81, 0x01])
  payload.append(segment_child([0x16, 0x54, 0xae, 0x6b], tracks_payload))
  match parse_segment_fixture(payload) {
    Err(Tracks(offset, Track(_, MissingRequired(id)))) => {
      assert_true(offset > 0)
      assert_eq(id, 0x73c5UL)
    }
    _ => fail("expected the nested TrackEntry error")
  }
}

///|
test "reject a non-Segment root element" {
  let bytes : Bytes = [0xa3, 0x80]
  match @ebml.read_element(bytes[:]) {
    Ok(element) =>
      match parse_segment(element) {
        Err(NotSegmentElement(id)) => assert_eq(id, 0xa3UL)
        _ => fail("expected a root element error")
      }
    Err(_) => fail("expected a valid fixture element")
  }
}
