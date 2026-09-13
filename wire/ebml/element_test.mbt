///|
test "read a bounded payload without copying it" {
  let bytes : Bytes = [0xa3, 0x82, 0xde, 0xad, 0xbe, 0xef]
  match read_element(bytes[:]) {
    Ok(element) => {
      assert_eq(element.header.element_id, 0xa3)
      assert_eq(element.payload.length(), 2)
      assert_eq(element.payload[0], 0xde)
      assert_eq(element.payload[1], 0xad)
      assert_eq(element.payload.start_offset(), 2)
      assert_true(element.extent is Bounded(4))
    }
    _ => fail("expected a bounded element")
  }
}

///|
test "reject a bounded payload that exceeds the input" {
  let bytes : Bytes = [0xa3, 0x84, 0xde]
  match read_element(bytes[:]) {
    Err(PayloadOutOfBounds(expected, available)) => {
      assert_eq(expected, 4)
      assert_eq(available, 1)
    }
    _ => fail("expected a payload bounds error")
  }
}

///|
test "treat an unknown-size payload as extending to the view end" {
  let bytes : Bytes = [0x18, 0x53, 0x80, 0x67, 0xff, 0xde, 0xad]
  match read_element(bytes[:]) {
    Ok(element) => {
      assert_eq(element.payload.length(), 2)
      assert_eq(element.payload[0], 0xde)
      assert_eq(element.payload[1], 0xad)
      assert_eq(element.payload.start_offset(), 5)
      assert_true(element.extent is ToEnd)
    }
    _ => fail("expected an unknown-size element")
  }
}

///|
test "allow an empty bounded payload" {
  let bytes : Bytes = [0xa3, 0x80]
  match read_element(bytes[:]) {
    Ok(element) => {
      assert_eq(element.payload.length(), 0)
      assert_true(element.extent is Bounded(2))
    }
    _ => fail("expected an empty element")
  }
}

///|
test "preserve absolute payload offsets for a sliced view" {
  let bytes : Bytes = [0xaa, 0xbb, 0x42, 0x86, 0x81, 0x99]
  match read_element(bytes.view(start=2)) {
    Ok(element) => {
      assert_eq(element.header.offset, 2)
      assert_eq(element.header.payload_offset, 5)
      assert_eq(element.payload.start_offset(), 5)
      assert_eq(element.payload[0], 0x99)
      assert_true(element.extent is Bounded(4))
    }
    _ => fail("expected a sliced element")
  }
}

///|
test "wrap header errors without losing their cause" {
  let bytes : Bytes = [0x00]
  match read_element(bytes[:]) {
    Err(Header(InvalidIdentifier(InvalidMarker(byte)))) => assert_eq(byte, 0x00)
    _ => fail("expected the header error to be preserved")
  }
}
