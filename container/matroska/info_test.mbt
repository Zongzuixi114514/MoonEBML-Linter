///|
fn info_bytes(payload : Array[Byte]) -> Bytes {
  let bytes : Array[Byte] = Array::new(capacity=payload.length() + 5)
  bytes.push(0x15)
  bytes.push(0x49)
  bytes.push(0xa9)
  bytes.push(0x66)
  bytes.push((0x80 + payload.length()).to_byte())
  for byte in payload {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn child(id : Array[Byte], payload : Array[Byte]) -> Array[Byte] {
  let bytes = Array::new(capacity=id.length() + payload.length() + 1)
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
fn parse_fixture(payload : Array[Byte]) -> Result[InfoMetadata, InfoError] {
  let bytes = info_bytes(payload)
  match @ebml.read_element(bytes[:]) {
    Ok(element) => parse_info(element)
    Err(error) => Err(Walk(@ebml.Element(0, error)))
  }
}

///|
test "parse Info metadata and normalize DateUTC" {
  let payload = Array::new(capacity=64)
  payload.append(child([0x2a, 0xd7, 0xb1], [0x0f, 0x42, 0x40]))
  payload.append(
    child([0x44, 0x89], [0x40, 0x49, 0x0f, 0xdb, 0x00, 0x00, 0x00, 0x00]),
  )
  payload.append(
    child([0x44, 0x61], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
  )
  payload.append(child([0x7b, 0xa9], [0x44, 0x65, 0x6d, 0x6f]))
  payload.append(child([0x4d, 0x80], [0x6d, 0x6f, 0x6f, 0x6e]))
  payload.append(child([0x57, 0x41], [0x6c, 0x69, 0x6e, 0x74]))
  match parse_fixture(payload) {
    Ok(info) => {
      assert_eq(info.timecode_scale, 1000000UL)
      assert_true(info.duration is Some(_))
      assert_eq(info.date_utc_unix_nanoseconds, Some(978307200000000000L))
      assert_eq(info.title, Some("Demo"))
      assert_eq(info.muxing_app, "moon")
      assert_eq(info.writing_app, "lint")
    }
    Err(_) => fail("expected valid Info metadata")
  }
}

///|
test "accept four-byte Duration values" {
  let payload = Array::new(capacity=32)
  payload.append(child([0x2a, 0xd7, 0xb1], [0x0f, 0x42, 0x40]))
  payload.append(child([0x44, 0x89], [0x3f, 0x80, 0x00, 0x00]))
  payload.append(child([0x4d, 0x80], [0x6d]))
  payload.append(child([0x57, 0x41], [0x77]))
  match parse_fixture(payload) {
    Ok(info) => assert_eq(info.duration, Some(1.0))
    Err(_) => fail("expected four-byte Duration to decode")
  }
}

///|
test "skip unknown Info children" {
  let payload = Array::new(capacity=24)
  payload.append(child([0x2a, 0xd7, 0xb1], [0x0f, 0x42, 0x40]))
  payload.append(child([0x81], [0xde, 0xad]))
  payload.append(child([0x4d, 0x80], [0x6d]))
  payload.append(child([0x57, 0x41], [0x77]))
  match parse_fixture(payload) {
    Ok(info) => assert_eq(info.timecode_scale, 1000000UL)
    Err(_) => fail("unknown Info children should be ignored")
  }
}

///|
test "report missing required Info children" {
  let payload = child([0x2a, 0xd7, 0xb1], [0x0f, 0x42, 0x40])
  match parse_fixture(payload) {
    Err(MissingRequired(id)) => assert_eq(id, 0x4d80UL)
    _ => fail("expected the first missing required field")
  }
}

///|
test "reject duplicate and invalid Info values" {
  let duplicate = Array::new(capacity=32)
  duplicate.append(child([0x2a, 0xd7, 0xb1], [0x0f, 0x42, 0x40]))
  duplicate.append(child([0x2a, 0xd7, 0xb1], [0x0f, 0x42, 0x40]))
  duplicate.append(child([0x4d, 0x80], [0x6d]))
  duplicate.append(child([0x57, 0x41], [0x77]))
  match parse_fixture(duplicate) {
    Err(DuplicateElement(id)) => assert_eq(id, 0x2ad7b1UL)
    _ => fail("expected duplicate detection")
  }
  let zero = Array::new(capacity=16)
  zero.append(child([0x2a, 0xd7, 0xb1], [0x00]))
  zero.append(child([0x4d, 0x80], [0x6d]))
  zero.append(child([0x57, 0x41], [0x77]))
  match parse_fixture(zero) {
    Err(InvalidTimecodeScale) => ()
    _ => fail("expected zero TimecodeScale to be rejected")
  }
}

///|
test "reject a non-Info root element" {
  let bytes : Bytes = [0xa3, 0x80]
  match @ebml.read_element(bytes[:]) {
    Ok(element) =>
      match parse_info(element) {
        Err(NotInfoElement(id)) => assert_eq(id, 0xa3UL)
        _ => fail("expected a root element error")
      }
    Err(_) => fail("expected a valid fixture element")
  }
}
