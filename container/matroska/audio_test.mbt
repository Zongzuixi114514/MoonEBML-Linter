///|
fn audio_bytes(payload : Array[Byte]) -> Bytes {
  let bytes : Array[Byte] = Array::new(capacity=payload.length() + 2)
  bytes.push(0xe1)
  bytes.push((0x80 + payload.length()).to_byte())
  for byte in payload {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn audio_child(id : Array[Byte], payload : Array[Byte]) -> Array[Byte] {
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
fn parse_audio_fixture(
  payload : Array[Byte],
) -> Result[AudioMetadata, AudioError] {
  let bytes = audio_bytes(payload)
  match @ebml.read_element(bytes[:]) {
    Ok(element) => parse_audio(element)
    Err(error) => Err(Walk(@ebml.Element(0, error)))
  }
}

///|
test "parse audio sampling and channel settings" {
  let payload = Array::new(capacity=40)
  payload.append(
    audio_child([0xb5], [0x40, 0x77, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00]),
  )
  payload.append(
    audio_child([0x78, 0xb5], [0x40, 0x77, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00]),
  )
  payload.append(audio_child([0x9f], [0x02]))
  payload.append(audio_child([0x62, 0x64], [0x10]))
  match parse_audio_fixture(payload) {
    Ok(audio) => {
      assert_eq(audio.sampling_frequency, 375.0)
      assert_eq(audio.output_sampling_frequency, Some(375.0))
      assert_eq(audio.channels, 2UL)
      assert_eq(audio.bit_depth, Some(16UL))
    }
    Err(_) => fail("expected valid Audio metadata")
  }
}

///|
test "accept four-byte sampling frequency" {
  let payload = Array::new(capacity=20)
  payload.append(audio_child([0xb5], [0x44, 0x7a, 0x00, 0x00]))
  payload.append(audio_child([0x9f], [0x01]))
  match parse_audio_fixture(payload) {
    Ok(audio) => {
      assert_eq(audio.sampling_frequency, 1000.0)
      assert_eq(audio.output_sampling_frequency, None)
    }
    Err(_) => fail("expected four-byte sampling frequency")
  }
}

///|
test "skip unknown Audio children" {
  let payload = Array::new(capacity=16)
  payload.append(audio_child([0x81], [0xde]))
  payload.append(audio_child([0xb5], [0x44, 0x7a, 0x00, 0x00]))
  payload.append(audio_child([0x9f], [0x01]))
  match parse_audio_fixture(payload) {
    Ok(audio) => assert_eq(audio.channels, 1UL)
    Err(_) => fail("unknown Audio children should be ignored")
  }
}

///|
test "report missing and invalid Audio values" {
  let missing = audio_child([0xb5], [0x44, 0x7a, 0x00, 0x00])
  match parse_audio_fixture(missing) {
    Err(MissingRequired(id)) => assert_eq(id, 0x9fUL)
    _ => fail("expected missing Channels")
  }
  let invalid_frequency = Array::new(capacity=16)
  invalid_frequency.append(audio_child([0xb5], [0x00, 0x00, 0x00, 0x00]))
  invalid_frequency.append(audio_child([0x9f], [0x01]))
  match parse_audio_fixture(invalid_frequency) {
    Err(InvalidFrequency(id)) => assert_eq(id, 0xb5UL)
    _ => fail("expected invalid sampling frequency")
  }
  let invalid_channels = Array::new(capacity=16)
  invalid_channels.append(audio_child([0xb5], [0x44, 0x7a, 0x00, 0x00]))
  invalid_channels.append(audio_child([0x9f], [0x00]))
  match parse_audio_fixture(invalid_channels) {
    Err(InvalidChannels) => ()
    _ => fail("expected invalid channel count")
  }
}

///|
test "reject duplicate and invalid Audio fields" {
  let duplicate = Array::new(capacity=20)
  duplicate.append(audio_child([0xb5], [0x44, 0x7a, 0x00, 0x00]))
  duplicate.append(audio_child([0xb5], [0x44, 0x7a, 0x00, 0x00]))
  duplicate.append(audio_child([0x9f], [0x01]))
  match parse_audio_fixture(duplicate) {
    Err(DuplicateElement(id)) => assert_eq(id, 0xb5UL)
    _ => fail("expected duplicate detection")
  }
  let invalid_bit_depth = Array::new(capacity=20)
  invalid_bit_depth.append(audio_child([0xb5], [0x44, 0x7a, 0x00, 0x00]))
  invalid_bit_depth.append(audio_child([0x9f], [0x01]))
  invalid_bit_depth.append(audio_child([0x62, 0x64], [0x00]))
  match parse_audio_fixture(invalid_bit_depth) {
    Err(InvalidBitDepth) => ()
    _ => fail("expected invalid bit depth")
  }
}

///|
test "reject a non-Audio root element" {
  let bytes : Bytes = [0xa3, 0x80]
  match @ebml.read_element(bytes[:]) {
    Ok(element) =>
      match parse_audio(element) {
        Err(NotAudioElement(id)) => assert_eq(id, 0xa3UL)
        _ => fail("expected a root element error")
      }
    Err(_) => fail("expected a valid fixture element")
  }
}
