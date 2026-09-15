///|
/// The collection of track entries carried by a Matroska `Tracks` element.
pub(all) struct TracksMetadata {
  entries : ReadOnlyArray[TrackMetadata]
} derive(Eq, Debug)

///|
/// Errors returned while decoding a Matroska `Tracks` element.
pub(all) enum TracksError {
  NotTracksElement(UInt64)
  Walk(@ebml.WalkError)
  Track(Int, TrackError)
  MissingTrackEntry
} derive(Eq, Debug)

///|
/// Parse all `TrackEntry` children in one Matroska `Tracks` element.
///
/// Child entries are decoded in wire order. Unknown extension elements are
/// ignored, while a malformed `TrackEntry` keeps its absolute byte offset.
pub fn parse_tracks(
  element : @ebml.ElementView,
) -> Result[TracksMetadata, TracksError] {
  if element.header.element_id != tracks_id {
    return Err(NotTracksElement(element.header.element_id))
  }
  let entries : Array[TrackMetadata] = []
  let walker = @ebml.ElementWalker::new(element.payload)
  while walker.remaining() > 0 {
    let child = match walker.next() {
      Ok(@ebml.End) => continue
      Ok(@ebml.Item(value)) => value
      Err(error) => return Err(Walk(error))
    }
    if child.header.element_id == track_entry_id {
      let entry = match parse_track_entry(child) {
        Ok(value) => value
        Err(error) => return Err(Track(child.header.offset, error))
      }
      entries.push(entry)
    }
  }
  if entries.length() == 0 {
    return Err(MissingTrackEntry)
  }
  Ok({ entries: ReadOnlyArray::from_array(entries[:]) })
}

///|
let tracks_id : UInt64 = 0x1654ae6bUL
