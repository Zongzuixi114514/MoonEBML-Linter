///|
/// The decoded payload of an EBML variable-size integer.
///
/// `Known` carries the payload and the number of bytes consumed. `Unknown`
/// represents the reserved all-ones payload used for an unknown element size.
pub(all) enum Vint {
  Known(UInt64, Int)
  Unknown(Int)
} derive(Eq, Debug)

///|
/// Errors produced while decoding the first EBML variable-size integer in a
/// byte view.
pub(all) enum VintError {
  NoInput
  InvalidMarker(Byte)
  Truncated(Int, Int)
} derive(Eq, Debug)

///|
/// Decode one EBML variable-size integer from the beginning of `input`.
///
/// The first set bit determines the encoded width. The marker bit is removed
/// from the first byte, while all following bytes remain part of the payload.
/// Extra bytes after the first value are intentionally left untouched so a
/// caller can continue parsing the enclosing element.
pub fn decode_vint(input : BytesView) -> Result[Vint, VintError] {
  if input.is_empty() {
    return Err(NoInput)
  }
  let width = marker_width(input[0])
  if width == 0 {
    return Err(InvalidMarker(input[0]))
  }
  let available = input.length()
  if available < width {
    return Err(Truncated(width, available))
  }
  let first_mask = (1 << (8 - width)) - 1
  let mut payload : UInt64 = (input[0].to_int() & first_mask).to_uint64()
  for index in 1..<width {
    payload = (payload << 8) | input[index].to_uint64()
  }
  let one : UInt64 = 1
  let unknown_payload = (one << (7 * width)) - one
  if payload == unknown_payload {
    Ok(Unknown(width))
  } else {
    Ok(Known(payload, width))
  }
}

///|
fn marker_width(first : Byte) -> Int {
  let value = first.to_int()
  if value >= 0x80 {
    1
  } else if value >= 0x40 {
    2
  } else if value >= 0x20 {
    3
  } else if value >= 0x10 {
    4
  } else if value >= 0x08 {
    5
  } else if value >= 0x04 {
    6
  } else if value >= 0x02 {
    7
  } else if value >= 0x01 {
    8
  } else {
    0
  }
}
