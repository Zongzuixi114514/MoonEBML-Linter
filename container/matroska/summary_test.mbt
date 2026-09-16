///|
test "segment summary counts tracks" {
  let payload = Array::new(capacity=64)
  payload.append(
    segment_child([0x15, 0x49, 0xa9, 0x66], segment_info_payload()),
  )
  let tracks_payload = Array::new(capacity=32)
  tracks_payload.append(segment_track_entry([0x56, 0x5f, 0x56, 0x50, 0x38]))
  tracks_payload.append(segment_audio_track_entry())
  payload.append(segment_child([0x16, 0x54, 0xae, 0x6b], tracks_payload))
  match parse_segment_fixture(payload) {
    Ok(segment) => {
      assert_eq(segment.track_count(), 2)
      assert_eq(segment.video_track_count(), 1)
      assert_eq(segment.audio_track_count(), 1)
      assert_eq(segment.duration_seconds(), None)
    }
    Err(_) => fail("expected a complete Segment summary")
  }
}

///|
fn segment_audio_track_entry() -> Array[Byte] {
  let payload = Array::new(capacity=16)
  payload.append(segment_child([0xd7], [0x02]))
  payload.append(segment_child([0x73, 0xc5], [0x02]))
  payload.append(segment_child([0x83], [0x02]))
  payload.append(segment_child([0x86], [0x41, 0x5f, 0x4f, 0x50, 0x55, 0x53]))
  segment_child([0xae], payload)
}
