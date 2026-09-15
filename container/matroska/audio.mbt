///|
/// Audio settings carried by a Matroska `Audio` master element.
pub(all) struct AudioMetadata {
  sampling_frequency : Double
  output_sampling_frequency : Double?
  channels : UInt64
  bit_depth : UInt64?
} derive(Eq, Debug)

///|
/// Errors returned while decoding a Matroska `Audio` element.
pub(all) enum AudioError {
  NotAudioElement(UInt64)
  Walk(@ebml.WalkError)
  Scalar(UInt64, @ebml.ScalarError)
  DuplicateElement(UInt64)
  MissingRequired(UInt64)
  InvalidFrequency(UInt64)
  InvalidChannels
  InvalidBitDepth
} derive(Eq, Debug)

///|
/// Parse one complete Matroska `Audio` element.
///
/// Unknown child IDs are ignored so newer Matroska extensions remain readable.
/// Sampling frequency and channel count must be positive.
pub fn parse_audio(
  element : @ebml.ElementView,
) -> Result[AudioMetadata, AudioError] {
  if element.header.element_id != audio_id {
    return Err(NotAudioElement(element.header.element_id))
  }
  let mut sampling_frequency : Double? = None
  let mut output_sampling_frequency : Double? = None
  let mut channels : UInt64? = None
  let mut bit_depth : UInt64? = None
  let walker = @ebml.ElementWalker::new(element.payload)
  while walker.remaining() > 0 {
    let child = match walker.next() {
      Ok(@ebml.End) => continue
      Ok(@ebml.Item(value)) => value
      Err(error) => return Err(Walk(error))
    }
    let child_id = child.header.element_id
    match child_id {
      0xb5UL => {
        if sampling_frequency is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match decode_audio_float(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        if value <= 0.0 {
          return Err(InvalidFrequency(child_id))
        }
        sampling_frequency = Some(value)
      }
      0x78b5UL => {
        if output_sampling_frequency is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match decode_audio_float(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        if value <= 0.0 {
          return Err(InvalidFrequency(child_id))
        }
        output_sampling_frequency = Some(value)
      }
      0x9fUL => {
        if channels is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        if value == 0UL {
          return Err(InvalidChannels)
        }
        channels = Some(value)
      }
      0x6264UL => {
        if bit_depth is Some(_) {
          return Err(DuplicateElement(child_id))
        }
        let value = match @ebml.decode_unsigned(child.payload) {
          Ok(value) => value
          Err(error) => return Err(Scalar(child_id, error))
        }
        if value == 0UL {
          return Err(InvalidBitDepth)
        }
        bit_depth = Some(value)
      }
      _ => ()
    }
  }
  let sampling = match sampling_frequency {
    Some(value) => value
    None => return Err(MissingRequired(sampling_frequency_id))
  }
  let channel_count = match channels {
    Some(value) => value
    None => return Err(MissingRequired(channels_id))
  }
  Ok({
    sampling_frequency: sampling,
    output_sampling_frequency,
    channels: channel_count,
    bit_depth,
  })
}

///|
fn decode_audio_float(input : BytesView) -> Result[Double, @ebml.ScalarError] {
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
let audio_id : UInt64 = 0xe1UL

///|
let sampling_frequency_id : UInt64 = 0xb5UL

///|
let channels_id : UInt64 = 0x9fUL
