///|
/// One step produced by an `ElementWalker`.
pub(all) enum WalkStep {
  Item(ElementView)
  End
} derive(Eq, Debug)

///|
/// Errors encountered while walking sibling EBML elements.
pub(all) enum WalkError {
  Element(Int, ElementReadError)
  NonProgress(Int)
} derive(Eq, Debug)

///|
/// A bounded, stateful cursor over sibling EBML elements.
///
/// The walker does not allocate an array of elements. Each call to `next`
/// returns one zero-copy `ElementView` and advances the cursor by the exact
/// number of bytes consumed by that element. An unknown-size element consumes
/// the rest of the supplied view because its boundary cannot be inferred from
/// the wire representation alone.
pub struct ElementWalker {
  input : BytesView
  mut cursor : Int
}

///|
/// Create a walker positioned at the beginning of `input`.
pub fn ElementWalker::new(input : BytesView) -> ElementWalker {
  { input, cursor: 0, }
}

///|
/// Return the cursor position relative to the supplied view.
pub fn ElementWalker::position(self : ElementWalker) -> Int {
  self.cursor
}

///|
/// Return the number of bytes that have not been visited yet.
pub fn ElementWalker::remaining(self : ElementWalker) -> Int {
  self.input.length() - self.cursor
}

///|
/// Read and advance to the next sibling element.
pub fn ElementWalker::next(self : ElementWalker) -> Result[WalkStep, WalkError] {
  if self.cursor == self.input.length() {
    return Ok(End)
  }
  let current = self.input.view(start=self.cursor)
  let element = match read_element(current) {
    Err(error) => return Err(Element(current.start_offset(), error))
    Ok(element) => element
  }
  let consumed = match element.extent {
    Bounded(bytes) => bytes
    ToEnd => self.input.length() - self.cursor
  }
  if consumed <= 0 {
    return Err(NonProgress(current.start_offset()))
  }
  self.cursor = self.cursor + consumed
  Ok(Item(element))
}
