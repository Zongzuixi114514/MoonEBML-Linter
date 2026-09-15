///|
test "walk bounded sibling elements in order" {
  let bytes : Bytes = [0xa3, 0x81, 0x01, 0x9f, 0x80]
  let walker = ElementWalker::new(bytes[:])
  assert_eq(walker.position(), 0)
  assert_eq(walker.remaining(), 5)
  match walker.next() {
    Ok(Item(element)) => {
      assert_eq(element.header.element_id, 0xa3)
      assert_eq(element.payload[0], 0x01)
      assert_eq(walker.position(), 3)
    }
    _ => fail("expected the first sibling element")
  }
  match walker.next() {
    Ok(Item(element)) => {
      assert_eq(element.header.element_id, 0x9f)
      assert_eq(element.payload.length(), 0)
      assert_eq(walker.position(), 5)
    }
    _ => fail("expected the second sibling element")
  }
  assert_eq(walker.remaining(), 0)
  assert_eq(walker.next(), Ok(End))
}

///|
test "an unknown-size element consumes the remaining view" {
  let bytes : Bytes = [0x18, 0x53, 0x80, 0x67, 0xff, 0xde, 0xad]
  let walker = ElementWalker::new(bytes[:])
  match walker.next() {
    Ok(Item(element)) => {
      assert_true(element.extent is ToEnd)
      assert_eq(element.payload.length(), 2)
      assert_eq(walker.position(), bytes.length())
    }
    _ => fail("expected an unknown-size element")
  }
  assert_eq(walker.next(), Ok(End))
}

///|
test "report the absolute offset of a malformed sibling" {
  let bytes : Bytes = [0xaa, 0xbb, 0xa3, 0x81, 0x01, 0x00]
  let walker = ElementWalker::new(bytes.view(start=2))
  match walker.next() {
    Ok(Item(element)) => assert_eq(element.header.offset, 2)
    _ => fail("expected the valid first element")
  }
  match walker.next() {
    Err(Element(offset, Header(InvalidIdentifier(InvalidMarker(byte))))) => {
      assert_eq(offset, 5)
      assert_eq(byte, 0x00)
    }
    _ => fail("expected the malformed sibling error")
  }
  assert_eq(walker.position(), 3)
}

///|
test "keep a zero-copy payload view while advancing" {
  let bytes : Bytes = [0xa3, 0x82, 0xde, 0xad, 0x9f, 0x80]
  let walker = ElementWalker::new(bytes[:])
  match walker.next() {
    Ok(Item(element)) => {
      assert_eq(element.payload.start_offset(), 2)
      assert_eq(element.payload.length(), 2)
      assert_eq(walker.position(), 4)
    }
    _ => fail("expected the payload-bearing element")
  }
  match walker.next() {
    Ok(Item(element)) => assert_eq(element.header.offset, 4)
    _ => fail("expected the following element")
  }
}
