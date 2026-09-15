///|
test "decode unsigned big-endian integers" {
  let bytes : Bytes = [0x01, 0x02, 0x03]
  assert_eq(decode_unsigned(bytes[:]), Ok(0x010203UL))
  let wide : Bytes = [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
  assert_eq(decode_unsigned(wide[:]), Ok(18446744073709551615UL))
}

///|
test "reject unsigned widths outside the EBML range" {
  let empty : Bytes = []
  let too_wide : Bytes = [0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_eq(decode_unsigned(empty[:]), Err(WidthOutOfRange(0)))
  assert_eq(decode_unsigned(too_wide[:]), Err(WidthOutOfRange(9)))
}

///|
test "decode signed values with sign extension" {
  let positive : Bytes = [0x7f]
  let negative_one : Bytes = [0xff]
  let negative_two : Bytes = [0xff, 0xfe]
  let negative_min : Bytes = [0x80, 0x00]
  assert_eq(decode_signed(positive[:]), Ok(127L))
  assert_eq(decode_signed(negative_one[:]), Ok(-1L))
  assert_eq(decode_signed(negative_two[:]), Ok(-2L))
  assert_eq(decode_signed(negative_min[:]), Ok(-32768L))
}

///|
test "decode IEEE-754 single precision" {
  let bytes : Bytes = [0x3f, 0x80, 0x00, 0x00]
  match decode_float32(bytes[:]) {
    Ok(value) => assert_eq(value.reinterpret_as_uint(), 0x3f800000U)
    Err(_) => fail("expected a float32 value")
  }
}

///|
test "decode IEEE-754 double precision" {
  let bytes : Bytes = [0x3f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  assert_eq(decode_float64(bytes[:]), Ok(1.0))
}

///|
test "require exact widths for floating-point values" {
  let bytes : Bytes = [0x00, 0x00, 0x00]
  assert_eq(decode_float32(bytes[:]), Err(ExactWidthRequired(4, 3)))
  assert_eq(decode_float64(bytes[:]), Err(ExactWidthRequired(8, 3)))
}

///|
test "decode valid and invalid UTF-8" {
  let text = @utf8.encode("MoonBit 容器")
  assert_eq(decode_utf8(text[:]), Ok("MoonBit 容器"))
  let invalid : Bytes = [0xff, 0xfe]
  assert_eq(decode_utf8(invalid[:]), Err(InvalidUtf8))
}

///|
test "decode and convert Matroska DateUTC" {
  let zero : Bytes = [0, 0, 0, 0, 0, 0, 0, 0]
  let one_second : Bytes = [0, 0, 0, 0, 0x3b, 0x9a, 0xca, 0x00]
  assert_eq(decode_date_utc(zero[:]), Ok(0L))
  assert_eq(decode_date_utc(one_second[:]), Ok(1000000000L))
  assert_eq(date_utc_to_unix_nanoseconds(1000000000L), 978307201000000000L)
}

///|
test "require an eight-byte Matroska DateUTC value" {
  let bytes : Bytes = [0, 0, 0]
  assert_eq(decode_date_utc(bytes[:]), Err(ExactWidthRequired(8, 3)))
}
