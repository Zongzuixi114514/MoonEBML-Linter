///|
/// The wire-level header of one EBML element.
///
/// `element_id` keeps the EBML marker bits because they are part of an
/// element identifier. `element_size` is decoded with the marker removed by
/// the VINT size decoder.
pub(all) struct ElementHeader {
  element_id : UInt64
  element_size : Vint
  offset : Int
  id_bytes : Int
  size_bytes : Int
  payload_offset : Int
} derive(Eq, Debug)

///|
/// Errors produced while reading an EBML element header.
pub(all) enum ElementHeaderError {
  InvalidIdentifier(VintError)
  InvalidSize(VintError)
} derive(Eq, Debug)

///|
/// Read one EBML element header from the beginning of `input`.
///
/// The returned offsets are relative to the original byte storage whenever
/// `input` is a `BytesView` slice. Only the header is consumed; the element
/// payload remains available to the caller.
pub fn read_element_header(
  input : BytesView,
) -> Result[ElementHeader, ElementHeaderError] {
  match read_element_id(input) {
    Err(error) => Err(InvalidIdentifier(error))
    Ok((element_id, id_bytes)) => {
      let size_input = input.view(start=id_bytes)
      match decode_vint(size_input) {
        Err(error) => Err(InvalidSize(error))
        Ok(element_size) => {
          let size_bytes = vint_bytes(element_size)
          let offset = input.start_offset()
          Ok({
            element_id,
            element_size,
            offset,
            id_bytes,
            size_bytes,
            payload_offset: offset + id_bytes + size_bytes,
          })
        }
      }
    }
  }
}

///|
fn read_element_id(input : BytesView) -> Result[(UInt64, Int), VintError] {
  if input.is_empty() {
    return Err(NoInput)
  }
  let id_bytes = marker_width(input[0])
  if id_bytes == 0 {
    return Err(InvalidMarker(input[0]))
  }
  let available = input.length()
  if available < id_bytes {
    return Err(Truncated(id_bytes, available))
  }
  let mut element_id : UInt64 = input[0].to_uint64()
  for index in 1..<id_bytes {
    element_id = (element_id << 8) | input[index].to_uint64()
  }
  Ok((element_id, id_bytes))
}

///|
fn vint_bytes(value : Vint) -> Int {
  match value {
    Known(_, width) => width
    Unknown(width) => width
  }
}
