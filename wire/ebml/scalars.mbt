///|
/// Errors returned by EBML scalar decoders.
pub(all) enum ScalarError {
  WidthOutOfRange(Int)
  ExactWidthRequired(Int, Int)
  InvalidUtf8
} derive(Eq, Debug)

///|
/// Decode an EBML unsigned integer stored in big-endian byte order.
///
/// EBML unsigned integer fields are between one and eight bytes wide. The
/// bytes are interpreted as a value, not as an EBML VINT, so no marker bit is
/// removed here.
pub fn decode_unsigned(input : BytesView) -> Result[UInt64, ScalarError] {
  decode_be_unsigned(input)
}

///|
/// Decode an EBML signed two's-complement integer in big-endian order.
pub fn decode_signed(input : BytesView) -> Result[Int64, ScalarError] {
  let raw = match decode_be_unsigned(input) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let width = input.length()
  let sign_set = (input[0].to_int() & 0x80) != 0
  let bits = if sign_set && width < 8 {
    let all_ones : UInt64 = 18446744073709551615UL
    raw | (all_ones << (8 * width))
  } else {
    raw
  }
  Ok(bits.reinterpret_as_int64())
}

///|
/// Decode an IEEE-754 single-precision value in big-endian order.
pub fn decode_float32(input : BytesView) -> Result[Float, ScalarError] {
  if input.length() != 4 {
    return Err(ExactWidthRequired(4, input.length()))
  }
  let mut bits : UInt = 0
  for index in 0..<4 {
    bits = (bits << 8) | input[index].to_uint()
  }
  Ok(Float::reinterpret_from_uint(bits))
}

///|
/// Decode an IEEE-754 double-precision value in big-endian order.
pub fn decode_float64(input : BytesView) -> Result[Double, ScalarError] {
  if input.length() != 8 {
    return Err(ExactWidthRequired(8, input.length()))
  }
  let bits = match decode_be_unsigned(input) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  Ok(bits.reinterpret_as_double())
}

///|
/// Decode a UTF-8 EBML string without copying the input before decoding.
pub fn decode_utf8(input : BytesView) -> Result[String, ScalarError] {
  Ok(@utf8.decode(input)) catch {
    _ => Err(InvalidUtf8)
  }
}

///|
/// Decode Matroska's signed eight-byte DateUTC scalar.
///
/// The returned value is a nanosecond offset from 2001-01-01 00:00:00 UTC.
pub fn decode_date_utc(input : BytesView) -> Result[Int64, ScalarError] {
  if input.length() != 8 {
    return Err(ExactWidthRequired(8, input.length()))
  }
  decode_signed(input)
}

///|
/// Convert a Matroska DateUTC offset to Unix epoch nanoseconds.
pub fn date_utc_to_unix_nanoseconds(value : Int64) -> Int64 {
  value + 978307200000000000L
}

///|
fn decode_be_unsigned(input : BytesView) -> Result[UInt64, ScalarError] {
  let width = input.length()
  if width < 1 || width > 8 {
    return Err(WidthOutOfRange(width))
  }
  let mut value : UInt64 = 0
  for index in 0..<width {
    value = (value << 8) | input[index].to_uint64()
  }
  Ok(value)
}
