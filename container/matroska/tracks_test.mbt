///|
fn tracks_bytes(payload : Array[Byte]) -> Bytes {
  let bytes : Array[Byte] = Array::new(capacity=payload.length() + 5)
  bytes.push(0x16)
  bytes.push(0x54)
  bytes.push(0xae)
  bytes.push(0x6b)
  bytes.push((0x80 + payload.length()).to_byte())
  for byte in payload {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn tracks_child(id : Array[Byte], payload : Array[Byte]) -> Array[Byte] {
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
fn track_entry_fixture(number : Int, codec : Array[Byte]) -> Array[Byte] {
  let payload = Array::new(capacity=20)
  payload.append(tracks_child([0xd7], [number.to_byte()]))
  payload.append(tracks_child([0x73, 0xc5], [number.to_byte()]))
  payload.append(tracks_child([0x83], [0x01]))
  payload.append(tracks_child([0x86], codec))
  tracks_child([0xae], payload)
}

///|
fn parse_tracks_fixture(
  payload : Array[Byte],
) -> Result[TracksMetadata, TracksError] {
  let bytes = tracks_bytes(payload)
  match @ebml.read_element(bytes[:]) {
    Ok(element) => parse_tracks(element)
    Err(error) => Err(Walk(@ebml.Element(0, error)))
  }
}

///|
test "parse multiple TrackEntry children in order" {
  let payload = Array::new(capacity=48)
  payload.append(track_entry_fixture(1, [0x56, 0x5f, 0x56, 0x50, 0x38]))
  payload.append(track_entry_fixture(2, [0x41, 0x5f, 0x4f, 0x50, 0x55, 0x53]))
  match parse_tracks_fixture(payload) {
    Ok(tracks) => {
      assert_eq(tracks.entries.length(), 2)
      assert_eq(tracks.entries[0].track_number, 1UL)
      assert_eq(tracks.entries[0].codec_id, "V_VP8")
      assert_eq(tracks.entries[1].track_number, 2UL)
      assert_eq(tracks.entries[1].codec_id, "A_OPUS")
    }
    Err(_) => fail("expected multiple TrackEntry children")
  }
}

///|
test "skip unknown Tracks children" {
  let payload = Array::new(capacity=24)
  payload.append(tracks_child([0x81], [0xde, 0xad]))
  payload.append(track_entry_fixture(1, [0x56]))
  match parse_tracks_fixture(payload) {
    Ok(tracks) => assert_eq(tracks.entries.length(), 1)
    Err(_) => fail("unknown Tracks children should be ignored")
  }
}

///|
test "report malformed TrackEntry offset" {
  let payload = Array::new(capacity=24)
  payload.append(track_entry_fixture(1, [0x56]))
  payload.append(tracks_child([0xae], [0xd7, 0x81, 0x01]))
  match parse_tracks_fixture(payload) {
    Err(Track(offset, MissingRequired(id))) => {
      assert_true(offset > 0)
      assert_eq(id, 0x73c5UL)
    }
    _ => fail("expected a nested TrackEntry error")
  }
}

///|
test "reject an empty Tracks element" {
  match parse_tracks_fixture([]) {
    Err(MissingTrackEntry) => ()
    _ => fail("expected the missing TrackEntry error")
  }
}

///|
test "reject a non-Tracks root element" {
  let bytes : Bytes = [0xa3, 0x80]
  match @ebml.read_element(bytes[:]) {
    Ok(element) =>
      match parse_tracks(element) {
        Err(NotTracksElement(id)) => assert_eq(id, 0xa3UL)
        _ => fail("expected a root element error")
      }
    Err(_) => fail("expected a valid fixture element")
  }
}
