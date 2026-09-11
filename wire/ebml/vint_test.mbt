///|
test "decode one-byte known payload" {
  let bytes : Bytes = [0x81]
  match decode_vint(bytes[:]) {
    Ok(Known(value, width)) => {
      assert_eq(value, 1)
      assert_eq(width, 1)
    }
    _ => fail("expected a one-byte known VINT")
  }
}

///|
test "decode two-byte known payload" {
  let bytes : Bytes = [0x40, 0x01]
  match decode_vint(bytes[:]) {
    Ok(Known(value, width)) => {
      assert_eq(value, 1)
      assert_eq(width, 2)
    }
    _ => fail("expected a two-byte known VINT")
  }
}

///|
test "recognize reserved unknown-size payloads" {
  let one_byte : Bytes = [0xff]
  let two_bytes : Bytes = [0x7f, 0xff]
  match (decode_vint(one_byte[:]), decode_vint(two_bytes[:])) {
    (Ok(Unknown(one_width)), Ok(Unknown(two_width))) => {
      assert_eq(one_width, 1)
      assert_eq(two_width, 2)
    }
    _ => fail("expected unknown-size VINTs")
  }
}

///|
test "keep the maximum known payload distinct from unknown" {
  let bytes : Bytes = [0x7f, 0xfe]
  match decode_vint(bytes[:]) {
    Ok(Known(value, width)) => {
      assert_eq(value, 0x3ffe)
      assert_eq(width, 2)
    }
    _ => fail("expected the largest known two-byte payload")
  }
}

///|
test "reject a zero marker" {
  let bytes : Bytes = [0x00]
  match decode_vint(bytes[:]) {
    Err(InvalidMarker(byte)) => assert_eq(byte, 0x00)
    _ => fail("expected an invalid marker error")
  }
}

///|
test "reject truncated input" {
  let bytes : Bytes = [0x40]
  match decode_vint(bytes[:]) {
    Err(Truncated(expected, available)) => {
      assert_eq(expected, 2)
      assert_eq(available, 1)
    }
    _ => fail("expected a truncation error")
  }
}

///|
test "decode only the first value from a longer view" {
  let bytes : Bytes = [0x81, 0xaa]
  match decode_vint(bytes[:]) {
    Ok(Known(value, width)) => {
      assert_eq(value, 1)
      assert_eq(width, 1)
    }
    _ => fail("expected the first VINT to be decoded")
  }
}

///|
test "reject empty input" {
  let bytes : Bytes = []
  match decode_vint(bytes[:]) {
    Err(NoInput) => ()
    _ => fail("expected a no-input error")
  }
}
