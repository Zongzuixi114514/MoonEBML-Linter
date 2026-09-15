///|
/// Metadata carried by one Matroska `TrackEntry` element.
pub(all) struct TrackMetadata {
  track_number : UInt64
  track_uid : UInt64
  track_type : UInt64
  codec_id : String
  name : String?
  language : String?
  default_duration_nanoseconds : UInt64?
  flag_default : Bool?
  flag_forced : Bool?
} derive(Eq, Debug)

///|
/// Errors returned while decoding a Matroska `TrackEntry` element.
pub(all) enum TrackError {
  NotTrackEntry(UInt64)
  Walk(@ebml.WalkError)
  Scalar(UInt64, @ebml.ScalarError)
  DuplicateElement(UInt64)
  MissingRequired(UInt64)
  InvalidFlag(UInt64, UInt64)
} derive(Eq, Debug)

///|
/// Parse one complete Matroska `TrackEntry` element.
///
/// Unknown child IDs are skipped so newer Matroska extensions remain readable.
/// Video and audio master elements are intentionally left for later parsers.
pub fn parse_track_entry(
  element : @ebml.ElementView,
) -> Result[TrackMetadata, TrackError] {
  if element.header.element_id != track_entry_id {
    return Err(NotTrackEntry(element.header.element_id))
  }
  let mut track_number : UInt64? = None
  let mut track_uid : UInt64? = None
  let mut track_type : UInt64? = None
  let mut codec_id : String? = None
  let mut name : String? = None
  let mut language : String? = None
  let mut default_duration_nanoseconds : UInt64? = None
  let mut flag_default : Bool? = None
  let mut flag_forced : Bool? = None
  let walker = @ebml.ElementWalker::new(element.payload)
  while walker.remaining() > 0 {
    let child = match walker.next() {
      Ok(@ebml.End) => continue
      Ok(@ebml.Item(value)) => value
      Err(error) => return Err(Walk(error))
    }
    let child_id = child.header.element_id
    match child_id {
      0xd7UL => {
        if track_number is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        track_number = Some(value)
      }
      0x73c5UL => {
        if track_uid is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        track_uid = Some(value)
      }
      0x83UL => {
        if track_type is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        track_type = Some(value)
      }
      0x86UL => {
        if codec_id is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_utf8(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        codec_id = Some(value)
      }
      0x536eUL => {
        if name is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_utf8(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        name = Some(value)
      }
      0x22b59cUL => {
        if language is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_utf8(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        language = Some(value)
      }
      0x23e383UL => {
        if default_duration_nanoseconds is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        default_duration_nanoseconds = Some(value)
      }
      0x88UL => {
        if flag_default is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match decode_flag(child.payload, child_id) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        flag_default = Some(value)
      }
      0x55aaUL => {
        if flag_forced is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match decode_flag(child.payload, child_id) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        flag_forced = Some(value)
      }
      _ => ()
    }
  }
  let number = match track_number {
    Some(value) => value
    None => return Err(MissingRequired(track_number_id))
  }
  let uid = match track_uid {
    Some(value) => value
    None => return Err(MissingRequired(track_uid_id))
  }
  let kind = match track_type {
    Some(value) => value
    None => return Err(MissingRequired(track_type_id))
  }
  let codec = match codec_id {
    Some(value) => value
    None => return Err(MissingRequired(codec_id_id))
  }
  Ok({
    track_number: number,
    track_uid: uid,
    track_type: kind,
    codec_id: codec,
    name,
    language,
    default_duration_nanoseconds,
    flag_default,
    flag_forced,
  })
}

///|
fn decode_flag(input : BytesView, id : UInt64) -> Result[Bool, TrackError] {
  let value = match @ebml.decode_unsigned(input) {
    Ok(value) => value
    Err(error) => return Err(Scalar(id, error))
  }
  match value {
    0UL => Ok(false)
    1UL => Ok(true)
    _ => Err(InvalidFlag(id, value))
  }
}

///|
let track_entry_id : UInt64 = 0xaeUL

///|
let track_number_id : UInt64 = 0xd7UL

///|
let track_uid_id : UInt64 = 0x73c5UL

///|
let track_type_id : UInt64 = 0x83UL

///|
let codec_id_id : UInt64 = 0x86UL
