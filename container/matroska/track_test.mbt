///|
fn track_entry_bytes(payload : Array[Byte]) -> Bytes {
  let bytes : Array[Byte] = Array::new(capacity=payload.length() + 2)
  bytes.push(0xae)
  bytes.push((0x80 + payload.length()).to_byte())
  for byte in payload {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn track_child(id : Array[Byte], payload : Array[Byte]) -> Array[Byte] {
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
fn parse_track_fixture(
  payload : Array[Byte],
) -> Result[TrackMetadata, TrackError] {
  let bytes = track_entry_bytes(payload)
  match @ebml.read_element(bytes[:]) {
    Ok(element) => parse_track_entry(element)
    Err(error) => Err(Walk(@ebml.Element(0, error)))
  }
}

///|
test "parse core TrackEntry metadata" {
  let payload = Array::new(capacity=64)
  payload.append(track_child([0xd7], [0x01]))
  payload.append(track_child([0x73, 0xc5], [0x12, 0x34]))
  payload.append(track_child([0x83], [0x01]))
  payload.append(track_child([0x86], [0x56, 0x5f, 0x56, 0x50, 0x38]))
  payload.append(track_child([0x53, 0x6e], [0x56, 0x69, 0x64, 0x65, 0x6f]))
  payload.append(track_child([0x22, 0xb5, 0x9c], [0x65, 0x6e, 0x67]))
  payload.append(track_child([0x23, 0xe3, 0x83], [0x00, 0x00, 0x00, 0x01]))
  payload.append(track_child([0x88], [0x01]))
  payload.append(track_child([0x55, 0xaa], [0x00]))
  match parse_track_fixture(payload) {
    Ok(track) => {
      assert_eq(track.track_number, 1UL)
      assert_eq(track.track_uid, 0x1234UL)
      assert_eq(track.track_type, 1UL)
      assert_eq(track.codec_id, "V_VP8")
      assert_eq(track.name, Some("Video"))
      assert_eq(track.language, Some("eng"))
      assert_eq(track.default_duration_nanoseconds, Some(1UL))
      assert_eq(track.flag_default, Some(true))
      assert_eq(track.flag_forced, Some(false))
    }
    Err(_) => fail("expected valid TrackEntry metadata")
  }
}

///|
test "skip unknown TrackEntry children" {
  let payload = Array::new(capacity=24)
  payload.append(track_child([0xd7], [0x01]))
  payload.append(track_child([0x81], [0xde, 0xad]))
  payload.append(track_child([0x73, 0xc5], [0x02]))
  payload.append(track_child([0x83], [0x02]))
  payload.append(track_child([0x86], [0x41]))
  match parse_track_fixture(payload) {
    Ok(track) => assert_eq(track.track_type, 2UL)
    Err(_) => fail("unknown TrackEntry children should be ignored")
  }
}

///|
test "report missing required TrackEntry fields" {
  let payload = track_child([0xd7], [0x01])
  match parse_track_fixture(payload) {
    Err(MissingRequired(id)) => assert_eq(id, 0x73c5UL)
    _ => fail("expected the first missing required field")
  }
}

///|
test "reject duplicate fields and invalid flags" {
  let duplicate = Array::new(capacity=24)
  duplicate.append(track_child([0xd7], [0x01]))
  duplicate.append(track_child([0xd7], [0x02]))
  duplicate.append(track_child([0x73, 0xc5], [0x01]))
  duplicate.append(track_child([0x83], [0x01]))
  duplicate.append(track_child([0x86], [0x41]))
  match parse_track_fixture(duplicate) {
    Err(DuplicateElement(id)) => assert_eq(id, 0xd7UL)
    _ => fail("expected duplicate detection")
  }
  let invalid_flag = Array::new(capacity=24)
  invalid_flag.append(track_child([0xd7], [0x01]))
  invalid_flag.append(track_child([0x73, 0xc5], [0x01]))
  invalid_flag.append(track_child([0x83], [0x01]))
  invalid_flag.append(track_child([0x86], [0x41]))
  invalid_flag.append(track_child([0x88], [0x02]))
  match parse_track_fixture(invalid_flag) {
    Err(InvalidFlag(id, value)) => {
      assert_eq(id, 0x88UL)
      assert_eq(value, 2UL)
    }
    _ => fail("expected invalid flag detection")
  }
}

///|
test "reject a non-TrackEntry root element" {
  let bytes : Bytes = [0xa3, 0x80]
  match @ebml.read_element(bytes[:]) {
    Ok(element) =>
      match parse_track_entry(element) {
        Err(NotTrackEntry(id)) => assert_eq(id, 0xa3UL)
        _ => fail("expected a root element error")
      }
    Err(_) => fail("expected a valid fixture element")
  }
}
