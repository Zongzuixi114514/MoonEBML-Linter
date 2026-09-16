///|
/// The metadata that can be discovered from a Matroska `Segment`.
pub(all) struct SegmentMetadata {
  info : InfoMetadata
  tracks : TracksMetadata
} derive(Eq, Debug)

///|
/// Errors returned while decoding a Matroska `Segment` element.
pub(all) enum SegmentError {
  NotSegmentElement(UInt64)
  Walk(@ebml.WalkError)
  Info(Int, InfoError)
  Tracks(Int, TracksError)
  DuplicateElement(UInt64)
  MissingRequired(UInt64)
} derive(Eq, Debug)

///|
/// Parse the required metadata masters in one Matroska `Segment`.
///
/// `Info` and `Tracks` are decoded in their wire order. Other segment-level
/// children, including clusters and future extensions, are skipped for now.
pub fn parse_segment(
  element : @ebml.ElementView,
) -> Result[SegmentMetadata, SegmentError] {
  if element.header.element_id != segment_id {
    return Err(NotSegmentElement(element.header.element_id))
  }
  let mut info : InfoMetadata? = None
  let mut tracks : TracksMetadata? = None
  let walker = @ebml.ElementWalker::new(element.payload)
  while walker.remaining() > 0 {
    let child = match walker.next() {
      Ok(@ebml.End) => continue
      Ok(@ebml.Item(value)) => value
      Err(error) => return Err(Walk(error))
    }
    let child_id = child.header.element_id
    match child_id {
      0x1549a966UL => {
        if info is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match parse_info(child) {
          Ok(value) => value
          Err(error) => return Err(Info(child.header.offset, error))
        }
        info = Some(value)
      }
      0x1654ae6bUL => {
        if tracks is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match parse_tracks(child) {
          Ok(value) => value
          Err(error) => return Err(Tracks(child.header.offset, error))
        }
        tracks = Some(value)
      }
      _ => ()
    }
  }
  let segment_info = match info {
    Some(value) => value
    None => return Err(MissingRequired(info_id))
  }
  let segment_tracks = match tracks {
    Some(value) => value
    None => return Err(MissingRequired(tracks_id))
  }
  Ok({ info: segment_info, tracks: segment_tracks, })
}

///|
let segment_id : UInt64 = 0x18538067UL
