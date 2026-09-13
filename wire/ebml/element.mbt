///|
/// Describes how many bytes of the input were consumed by an element.
///
/// `Bounded` is used for a known element size and stores the total number of
/// bytes consumed, including the element header. `ToEnd` is used for an
/// unknown-size element whose payload extends to the end of the supplied view.
pub(all) enum ElementExtent {
  Bounded(Int)
  ToEnd
} derive(Eq, Debug)

///|
/// An EBML element header together with a zero-copy view of its payload.
pub(all) struct ElementView {
  header : ElementHeader
  payload : BytesView
  extent : ElementExtent
} derive(Eq, Debug)

///|
/// Errors produced while pairing an EBML header with its payload bytes.
pub(all) enum ElementReadError {
  Header(ElementHeaderError)
  PayloadLengthOverflow(UInt64)
  PayloadOutOfBounds(UInt64, Int)
} derive(Eq, Debug)

///|
/// Read one complete EBML element from the beginning of `input`.
///
/// The payload is returned as a zero-copy `BytesView`. A known-size element
/// must fit entirely inside `input`; an unknown-size element consumes the rest
/// of the view and is marked with `ElementExtent::ToEnd`.
pub fn read_element(input : BytesView) -> Result[ElementView, ElementReadError] {
  let header = match read_element_header(input) {
    Err(error) => return Err(Header(error))
    Ok(header) => header
  }
  let body_start = header.id_bytes + header.size_bytes
  match header.element_size {
    Known(size, _) => {
      let payload_size = size.to_int()
      if payload_size.to_uint64() != size {
        return Err(PayloadLengthOverflow(size))
      }
      let available = input.length() - body_start
      if payload_size > available {
        return Err(PayloadOutOfBounds(size, available))
      }
      let body_end = body_start + payload_size
      Ok({
        header,
        payload: input.view(start=body_start, end=body_end),
        extent: Bounded(body_end),
      })
    }
    Unknown(_) =>
      Ok({ header, payload: input.view(start=body_start), extent: ToEnd })
  }
}
