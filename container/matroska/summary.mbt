///|
/// Return the number of tracks described by this segment.
pub fn SegmentMetadata::track_count(self : SegmentMetadata) -> Int {
  self.tracks.entries.length()
}

///|
/// Count video tracks (`TrackType = 1`) in this segment.
pub fn SegmentMetadata::video_track_count(self : SegmentMetadata) -> Int {
  let mut count = 0
  for track in self.tracks.entries {
    if track.track_type == 1UL {
      count += 1
    }
  }
  count
}

///|
/// Count audio tracks (`TrackType = 2`) in this segment.
pub fn SegmentMetadata::audio_track_count(self : SegmentMetadata) -> Int {
  let mut count = 0
  for track in self.tracks.entries {
    if track.track_type == 2UL {
      count += 1
    }
  }
  count
}

///|
/// Convert the Info duration to seconds when a duration is present.
///
/// Matroska stores duration in timecode units. The result applies the
/// segment's `timecode_scale` and returns `None` when the field is absent.
pub fn SegmentMetadata::duration_seconds(self : SegmentMetadata) -> Double? {
  match self.info.duration {
    Some(duration) =>
      Some(duration * self.info.timecode_scale.to_double() / 1_000_000_000.0)
    None => None
  }
}
