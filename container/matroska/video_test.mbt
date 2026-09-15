///|
fn video_bytes(payload : Array[Byte]) -> Bytes {
  let bytes : Array[Byte] = Array::new(capacity=payload.length() + 2)
  bytes.push(0xe0)
  bytes.push((0x80 + payload.length()).to_byte())
  for byte in payload {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn video_child(id : Array[Byte], payload : Array[Byte]) -> Array[Byte] {
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
fn parse_video_fixture(
  payload : Array[Byte],
) -> Result[VideoMetadata, VideoError] {
  let bytes = video_bytes(payload)
  match @ebml.read_element(bytes[:]) {
    Ok(element) => parse_video(element)
    Err(error) => Err(Walk(@ebml.Element(0, error)))
  }
}

///|
test "parse video dimensions and display settings" {
  let payload = Array::new(capacity=64)
  payload.append(video_child([0xb0], [0x07, 0x80]))
  payload.append(video_child([0xba], [0x04, 0x38]))
  payload.append(video_child([0x54, 0xb0], [0x0f, 0x00]))
  payload.append(video_child([0x54, 0xba], [0x08, 0x70]))
  payload.append(video_child([0x54, 0xb2], [0x01]))
  payload.append(video_child([0x23, 0x83, 0xe3], [0x41, 0x20, 0x00, 0x00]))
  payload.append(video_child([0x53, 0xb8], [0x01]))
  payload.append(video_child([0x9a], [0x01]))
  match parse_video_fixture(payload) {
    Ok(video) => {
      assert_eq(video.pixel_width, 1920UL)
      assert_eq(video.pixel_height, 1080UL)
      assert_eq(video.display_width, Some(3840UL))
      assert_eq(video.display_height, Some(2160UL))
      assert_eq(video.display_unit, Some(1UL))
      assert_eq(video.frame_rate, Some(10.0))
      assert_eq(video.stereo_mode, Some(1UL))
      assert_eq(video.flag_interlaced, Some(true))
    }
    Err(_) => fail("expected valid Video metadata")
  }
}

///|
test "allow required dimensions without optional settings" {
  let payload = Array::new(capacity=16)
  payload.append(video_child([0xb0], [0x01]))
  payload.append(video_child([0xba], [0x01]))
  match parse_video_fixture(payload) {
    Ok(video) => {
      assert_eq(video.pixel_width, 1UL)
      assert_eq(video.pixel_height, 1UL)
      assert_eq(video.frame_rate, None)
    }
    Err(_) => fail("expected minimal Video metadata")
  }
}

///|
test "skip unknown Video children" {
  let payload = Array::new(capacity=16)
  payload.append(video_child([0x81], [0xde]))
  payload.append(video_child([0xb0], [0x01]))
  payload.append(video_child([0xba], [0x01]))
  match parse_video_fixture(payload) {
    Ok(video) => assert_eq(video.pixel_width, 1UL)
    Err(_) => fail("unknown Video children should be ignored")
  }
}

///|
test "report missing and invalid Video values" {
  let missing = video_child([0xb0], [0x01])
  match parse_video_fixture(missing) {
    Err(MissingRequired(id)) => assert_eq(id, 0xbaUL)
    _ => fail("expected missing PixelHeight")
  }
  let zero = Array::new(capacity=8)
  zero.append(video_child([0xb0], [0x00]))
  zero.append(video_child([0xba], [0x01]))
  match parse_video_fixture(zero) {
    Err(InvalidDimension(id)) => assert_eq(id, 0xb0UL)
    _ => fail("expected zero PixelWidth rejection")
  }
}

///|
test "reject duplicate and invalid Video flags" {
  let duplicate = Array::new(capacity=16)
  duplicate.append(video_child([0xb0], [0x01]))
  duplicate.append(video_child([0xb0], [0x02]))
  duplicate.append(video_child([0xba], [0x01]))
  match parse_video_fixture(duplicate) {
    Err(DuplicateElement(id)) => assert_eq(id, 0xb0UL)
    _ => fail("expected duplicate detection")
  }
  let invalid = Array::new(capacity=16)
  invalid.append(video_child([0xb0], [0x01]))
  invalid.append(video_child([0xba], [0x01]))
  invalid.append(video_child([0x9a], [0x02]))
  match parse_video_fixture(invalid) {
    Err(InvalidFlag(id, value)) => {
      assert_eq(id, 0x9aUL)
      assert_eq(value, 2UL)
    }
    _ => fail("expected invalid flag detection")
  }
}

///|
test "reject a non-Video root element" {
  let bytes : Bytes = [0xa3, 0x80]
  match @ebml.read_element(bytes[:]) {
    Ok(element) =>
      match parse_video(element) {
        Err(NotVideoElement(id)) => assert_eq(id, 0xa3UL)
        _ => fail("expected a root element error")
      }
    Err(_) => fail("expected a valid fixture element")
  }
}
