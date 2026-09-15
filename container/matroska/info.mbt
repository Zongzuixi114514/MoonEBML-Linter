///|
/// Metadata carried by a Matroska `Info` element.
///
/// `date_utc_unix_nanoseconds` is expressed on the Unix epoch. `duration` is
/// measured in segment timecode units after applying `timecode_scale`.
pub(all) struct InfoMetadata {
  timecode_scale : UInt64
  duration : Double?
  date_utc_unix_nanoseconds : Int64?
  title : String?
  muxing_app : String
  writing_app : String
} derive(Eq, Debug)

///|
/// Errors returned while decoding a Matroska `Info` element.
pub(all) enum InfoError {
  NotInfoElement(UInt64)
  Walk(@ebml.WalkError)
  Scalar(UInt64, @ebml.ScalarError)
  DuplicateElement(UInt64)
  MissingRequired(UInt64)
  InvalidTimecodeScale
} derive(Eq, Debug)

///|
/// Parse one complete Matroska `Info` element.
///
/// Unknown child IDs are skipped so that extensions remain forward-compatible.
/// Known scalar children are decoded without copying their payload bytes.
pub fn parse_info(
  element : @ebml.ElementView,
) -> Result[InfoMetadata, InfoError] {
  if element.header.element_id != info_id {
    return Err(NotInfoElement(element.header.element_id))
  }
  let mut timecode_scale : UInt64? = None
  let mut duration : Double? = None
  let mut date_utc_unix_nanoseconds : Int64? = None
  let mut title : String? = None
  let mut muxing_app : String? = None
  let mut writing_app : String? = None
  let walker = @ebml.ElementWalker::new(element.payload)
  while walker.remaining() > 0 {
    let child = match walker.next() {
      Ok(@ebml.End) => continue
      Ok(@ebml.Item(value)) => value
      Err(error) => return Err(Walk(error))
    }
    let child_id = child.header.element_id
    match child_id {
      0x2ad7b1UL => {
        if timecode_scale is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        if value == 0UL {
          return Err(InvalidTimecodeScale)
        }
        timecode_scale = Some(value)
      }
      0x4489UL => {
        if duration is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match decode_duration(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        duration = Some(value)
      }
      0x4461UL => {
        if date_utc_unix_nanoseconds is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_date_utc(child.payload) {
          Ok(value) => @ebml.date_utc_to_unix_nanoseconds(value)
          Err(error) => return Err(Scalar(child_id, error))
        }
        date_utc_unix_nanoseconds = Some(value)
      }
      0x7ba9UL => {
        if title is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_utf8(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        title = Some(value)
      }
      0x4d80UL => {
        if muxing_app is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_utf8(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        muxing_app = Some(value)
      }
      0x5741UL => {
        if writing_app is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_utf8(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        writing_app = Some(value)
      }
      _ => ()
    }
  }
  let scale = match timecode_scale {
    Some(value) => value
    None => return Err(MissingRequired(timecode_scale_id))
  }
  let muxing = match muxing_app {
    Some(value) => value
    None => return Err(MissingRequired(muxing_app_id))
  }
  let writing = match writing_app {
    Some(value) => value
    None => return Err(MissingRequired(writing_app_id))
  }
  Ok({
    timecode_scale: scale,
    duration,
    date_utc_unix_nanoseconds,
    title,
    muxing_app: muxing,
    writing_app: writing,
  })
}

///|
fn decode_duration(input : BytesView) -> Result[Double, @ebml.ScalarError] {
  match input.length() {
    4 =>
      match @ebml.decode_float32(input) {
        Ok(value) => Ok(value.to_double())
        Err(error) => Err(error)
      }
    8 => @ebml.decode_float64(input)
    width => Err(@ebml.ExactWidthRequired(8, width))
  }
}

///|
let info_id : UInt64 = 0x1549a966UL

///|
let timecode_scale_id : UInt64 = 0x2ad7b1UL

///|
let muxing_app_id : UInt64 = 0x4d80UL

///|
let writing_app_id : UInt64 = 0x5741UL
