///|
test "read an EBML header with a four-byte identifier" {
  let bytes : Bytes = [0x1a, 0x45, 0xdf, 0xa3, 0x9f]
  match read_element_header(bytes[:]) {
    Ok(header) => {
      assert_eq(header.element_id, 0x1a45dfa3)
      assert_true(header.element_size is Known(31, 1))
      assert_eq(header.offset, 0)
      assert_eq(header.id_bytes, 4)
      assert_eq(header.size_bytes, 1)
      assert_eq(header.payload_offset, 5)
    }
    _ => fail("expected an EBML header")
  }
}

///|
test "preserve an eight-byte unknown element size" {
  let bytes : Bytes = [
    0x18, 0x53, 0x80, 0x67, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  ]
  match read_element_header(bytes[:]) {
    Ok(header) => {
      assert_eq(header.element_id, 0x18538067)
      assert_true(header.element_size is Unknown(8))
      assert_eq(header.id_bytes, 4)
      assert_eq(header.size_bytes, 8)
      assert_eq(header.payload_offset, 12)
    }
    _ => fail("expected an unknown-size Segment header")
  }
}

///|
test "keep the source offset of a sliced view" {
  let bytes : Bytes = [0xaa, 0xbb, 0x42, 0x86, 0x40, 0x01]
  let view = bytes.view(start=2)
  match read_element_header(view) {
    Ok(header) => {
      assert_eq(header.element_id, 0x4286)
      assert_true(header.element_size is Known(1, 2))
      assert_eq(header.offset, 2)
      assert_eq(header.payload_offset, 6)
    }
    _ => fail("expected a header at the view offset")
  }
}

///|
test "retain marker bits in a one-byte element identifier" {
  let bytes : Bytes = [0xa3, 0x80]
  match read_element_header(bytes[:]) {
    Ok(header) => {
      assert_eq(header.element_id, 0xa3)
      assert_true(header.element_size is Known(0, 1))
      assert_eq(header.payload_offset, 2)
    }
    _ => fail("expected a zero-length element")
  }
}

///|
test "report an invalid identifier" {
  let bytes : Bytes = [0x00, 0x81]
  match read_element_header(bytes[:]) {
    Err(InvalidIdentifier(InvalidMarker(byte))) => assert_eq(byte, 0x00)
    _ => fail("expected an invalid identifier error")
  }
}

///|
test "report a truncated identifier" {
  let bytes : Bytes = [0x1a, 0x45]
  match read_element_header(bytes[:]) {
    Err(InvalidIdentifier(Truncated(expected, available))) => {
      assert_eq(expected, 4)
      assert_eq(available, 2)
    }
    _ => fail("expected a truncated identifier error")
  }
}

///|
test "report a truncated size" {
  let bytes : Bytes = [0x42, 0x86, 0x40]
  match read_element_header(bytes[:]) {
    Err(InvalidSize(Truncated(expected, available))) => {
      assert_eq(expected, 2)
      assert_eq(available, 1)
    }
    _ => fail("expected a truncated size error")
  }
}

///|
test "ignore bytes after the element header" {
  let bytes : Bytes = [0xa3, 0x81, 0xde, 0xad]
  match read_element_header(bytes[:]) {
    Ok(header) => {
      assert_eq(header.element_id, 0xa3)
      assert_true(header.element_size is Known(1, 1))
      assert_eq(header.payload_offset, 2)
    }
    _ => fail("expected trailing payload bytes to be untouched")
  }
}
