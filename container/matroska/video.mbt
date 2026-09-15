///|
/// Video settings carried by a Matroska `Video` master element.
pub(all) struct VideoMetadata {
  pixel_width : UInt64
  pixel_height : UInt64
  display_width : UInt64?
  display_height : UInt64?
  display_unit : UInt64?
  frame_rate : Double?
  stereo_mode : UInt64?
  flag_interlaced : Bool?
} derive(Eq, Debug)

///|
/// Errors returned while decoding a Matroska `Video` element.
pub(all) enum VideoError {
  NotVideoElement(UInt64)
  Walk(@ebml.WalkError)
  Scalar(UInt64, @ebml.ScalarError)
  DuplicateElement(UInt64)
  MissingRequired(UInt64)
  InvalidFlag(UInt64, UInt64)
  InvalidDimension(UInt64)
} derive(Eq, Debug)

///|
/// Parse one complete Matroska `Video` element.
///
/// Unknown child IDs are ignored so the parser remains compatible with
/// extensions. Pixel dimensions are required and must be non-zero.
pub fn parse_video(
  element : @ebml.ElementView,
) -> Result[VideoMetadata, VideoError] {
  if element.header.element_id != video_id {
    return Err(NotVideoElement(element.header.element_id))
  }
  let mut pixel_width : UInt64? = None
  let mut pixel_height : UInt64? = None
  let mut display_width : UInt64? = None
  let mut display_height : UInt64? = None
  let mut display_unit : UInt64? = None
  let mut frame_rate : Double? = None
  let mut stereo_mode : UInt64? = None
  let mut flag_interlaced : Bool? = None
  let walker = @ebml.ElementWalker::new(element.payload)
  while walker.remaining() > 0 {
    let child = match walker.next() {
      Ok(@ebml.End) => continue
      Ok(@ebml.Item(value)) => value
      Err(error) => return Err(Walk(error))
    }
    let child_id = child.header.element_id
    match child_id {
      0xb0UL => {
        if pixel_width is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        if value == 0UL {
          return Err(InvalidDimension(child_id))
        }
        pixel_width = Some(value)
      }
      0xbaUL => {
        if pixel_height is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        if value == 0UL {
          return Err(InvalidDimension(child_id))
        }
        pixel_height = Some(value)
      }
      0x54b0UL => {
        if display_width is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        display_width = Some(value)
      }
      0x54baUL => {
        if display_height is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        display_height = Some(value)
      }
      0x54b2UL => {
        if display_unit is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        display_unit = Some(value)
      }
      0x2383e3UL => {
        if frame_rate is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match decode_frame_rate(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        frame_rate = Some(value)
      }
      0x53b8UL => {
        if stereo_mode is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        stereo_mode = Some(value)
      }
      0x9aUL => {
        if flag_interlaced is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match decode_video_flag(child.payload, child_id) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        flag_interlaced = Some(value)
      }
      _ => ()
    }
  }
  let width = match pixel_width {
    Some(value) => value
    None => return Err(MissingRequired(pixel_width_id))
  }
  let height = match pixel_height {
    Some(value) => value
    None => return Err(MissingRequired(pixel_height_id))
  }
  Ok({
    pixel_width: width,
    pixel_height: height,
    display_width,
    display_height,
    display_unit,
    frame_rate,
    stereo_mode,
    flag_interlaced,
  })
}

///|
fn decode_frame_rate(input : BytesView) -> Result[Double, @ebml.ScalarError] {
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
fn decode_video_flag(
  input : BytesView,
  id : UInt64,
) -> Result[Bool, VideoError] {
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
let video_id : UInt64 = 0xe0UL

///|
let pixel_width_id : UInt64 = 0xb0UL

///|
let pixel_height_id : UInt64 = 0xbaUL
