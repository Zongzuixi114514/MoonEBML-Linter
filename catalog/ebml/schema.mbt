///|
/// The payload encoding of a known EBML element.
pub(all) enum PayloadKind {
  Master
  Unsigned
  Signed
  Float
  Utf8
  Binary
  DateUtc
} derive(Eq, Debug)

///|
/// How often an element may occur in its parent.
pub(all) enum Occurrence {
  Required
  Optional
  Repeated
} derive(Eq, Debug)

///|
/// The schema metadata needed to identify and dispatch a known EBML element.
pub(all) struct ElementSpec {
  id : UInt64
  name : String
  kind : PayloadKind
  level : Int
  occurrence : Occurrence
  parent_id : UInt64?
} derive(Eq, Debug)

///|
/// Look up one element in the curated Matroska/WebM schema catalog.
///
/// The catalog intentionally starts with the structures needed by the
/// inspector MVP: EBML header, Segment metadata, tracks, clusters, and cues.
/// Unknown IDs remain valid wire elements and simply return `None` here.
pub fn lookup_element(id : UInt64) -> ElementSpec? {
  for item in element_schema {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
/// Return the catalog as a read-only array for diagnostics and documentation.
pub fn all_elements() -> ReadOnlyArray[ElementSpec] {
  ReadOnlyArray::from_array(element_schema[:])
}

///|
/// Number of entries currently covered by the curated catalog.
pub fn element_count() -> Int {
  element_schema.length()
}

///|
fn spec(
  id : UInt64,
  name : String,
  kind : PayloadKind,
  level : Int,
  occurrence : Occurrence,
  parent_id : UInt64?,
) -> ElementSpec {
  { id, name, kind, level, occurrence, parent_id, }
}

///|
let ebml_id : UInt64 = 0x1a45dfa3UL

///|
let segment_id : UInt64 = 0x18538067UL

///|
let info_id : UInt64 = 0x1549a966UL

///|
let tracks_id : UInt64 = 0x1654ae6bUL

///|
let track_entry_id : UInt64 = 0xaeUL

///|
let video_id : UInt64 = 0xe0UL

///|
let audio_id : UInt64 = 0xe1UL

///|
let cluster_id : UInt64 = 0x1f43b675UL

///|
let block_group_id : UInt64 = 0xa0UL

///|
let cues_id : UInt64 = 0x1c53bb6bUL

///|
let cue_point_id : UInt64 = 0xbbUL

///|
let cue_track_positions_id : UInt64 = 0xb7UL

///|
let element_schema : Array[ElementSpec] = [
  // EBML header.
  spec(ebml_id, "EBML", Master, 0, Required, None),
  spec(0x4286UL, "EBMLVersion", Unsigned, 1, Required, Some(ebml_id)),
  spec(0x42f7UL, "EBMLReadVersion", Unsigned, 1, Required, Some(ebml_id)),
  spec(0x42f2UL, "EBMLMaxIDLength", Unsigned, 1, Required, Some(ebml_id)),
  spec(0x42f3UL, "EBMLMaxSizeLength", Unsigned, 1, Required, Some(ebml_id)),
  spec(0x4282UL, "DocType", Utf8, 1, Required, Some(ebml_id)),
  spec(0x4287UL, "DocTypeVersion", Unsigned, 1, Required, Some(ebml_id)),
  spec(0x4285UL, "DocTypeReadVersion", Unsigned, 1, Required, Some(ebml_id)),

  // Segment-level masters.
  spec(segment_id, "Segment", Master, 0, Required, None),
  spec(0x114d9b74UL, "SeekHead", Master, 1, Repeated, Some(segment_id)),
  spec(info_id, "Info", Master, 1, Required, Some(segment_id)),
  spec(tracks_id, "Tracks", Master, 1, Required, Some(segment_id)),
  spec(0x1043a770UL, "Chapters", Master, 1, Repeated, Some(segment_id)),
  spec(cues_id, "Cues", Master, 1, Optional, Some(segment_id)),
  spec(0x1254c367UL, "Tags", Master, 1, Repeated, Some(segment_id)),
  spec(0x1941a469UL, "Attachments", Master, 1, Optional, Some(segment_id)),
  spec(cluster_id, "Cluster", Master, 1, Repeated, Some(segment_id)),

  // Segment information.
  spec(0x73a4UL, "SegmentUID", Binary, 2, Optional, Some(info_id)),
  spec(0x7384UL, "SegmentFilename", Utf8, 2, Optional, Some(info_id)),
  spec(0x3cb923UL, "PrevUID", Binary, 2, Optional, Some(info_id)),
  spec(0x3c83UL, "PrevFilename", Utf8, 2, Optional, Some(info_id)),
  spec(0x3eb923UL, "NextUID", Binary, 2, Optional, Some(info_id)),
  spec(0x3e83UL, "NextFilename", Utf8, 2, Optional, Some(info_id)),
  spec(0x4444UL, "SegmentFamily", Binary, 2, Repeated, Some(info_id)),
  spec(0x2ad7b1UL, "TimecodeScale", Unsigned, 2, Required, Some(info_id)),
  spec(0x4489UL, "Duration", Float, 2, Optional, Some(info_id)),
  spec(0x4461UL, "DateUTC", DateUtc, 2, Optional, Some(info_id)),
  spec(0x7ba9UL, "Title", Utf8, 2, Optional, Some(info_id)),
  spec(0x4d80UL, "MuxingApp", Utf8, 2, Required, Some(info_id)),
  spec(0x5741UL, "WritingApp", Utf8, 2, Required, Some(info_id)),

  // Track entries and common track metadata.
  spec(track_entry_id, "TrackEntry", Master, 2, Repeated, Some(tracks_id)),
  spec(0xd7UL, "TrackNumber", Unsigned, 3, Required, Some(track_entry_id)),
  spec(0x73c5UL, "TrackUID", Unsigned, 3, Required, Some(track_entry_id)),
  spec(0x83UL, "TrackType", Unsigned, 3, Required, Some(track_entry_id)),
  spec(0xb9UL, "FlagEnabled", Unsigned, 3, Optional, Some(track_entry_id)),
  spec(0x88UL, "FlagDefault", Unsigned, 3, Optional, Some(track_entry_id)),
  spec(0x55aaUL, "FlagForced", Unsigned, 3, Optional, Some(track_entry_id)),
  spec(0x9cUL, "FlagLacing", Unsigned, 3, Optional, Some(track_entry_id)),
  spec(
    0x23e383UL,
    "DefaultDuration",
    Unsigned,
    3,
    Optional,
    Some(track_entry_id),
  ),
  spec(0x536eUL, "Name", Utf8, 3, Optional, Some(track_entry_id)),
  spec(0x22b59cUL, "Language", Utf8, 3, Optional, Some(track_entry_id)),
  spec(0x22b59dUL, "LanguageBCP47", Utf8, 3, Optional, Some(track_entry_id)),
  spec(0x86UL, "CodecID", Utf8, 3, Required, Some(track_entry_id)),
  spec(0x63a2UL, "CodecPrivate", Binary, 3, Optional, Some(track_entry_id)),
  spec(0x258688UL, "CodecName", Utf8, 3, Optional, Some(track_entry_id)),
  spec(video_id, "Video", Master, 3, Optional, Some(track_entry_id)),
  spec(audio_id, "Audio", Master, 3, Optional, Some(track_entry_id)),

  // Video settings.
  spec(0x9aUL, "FlagInterlaced", Unsigned, 4, Optional, Some(video_id)),
  spec(0x53b8UL, "StereoMode", Unsigned, 4, Optional, Some(video_id)),
  spec(0xb0UL, "PixelWidth", Unsigned, 4, Required, Some(video_id)),
  spec(0xbaUL, "PixelHeight", Unsigned, 4, Required, Some(video_id)),
  spec(0x54b0UL, "DisplayWidth", Unsigned, 4, Optional, Some(video_id)),
  spec(0x54baUL, "DisplayHeight", Unsigned, 4, Optional, Some(video_id)),
  spec(0x54b2UL, "DisplayUnit", Unsigned, 4, Optional, Some(video_id)),
  spec(0x2383e3UL, "FrameRate", Float, 4, Optional, Some(video_id)),

  // Audio settings.
  spec(0xb5UL, "SamplingFrequency", Float, 4, Required, Some(audio_id)),
  spec(0x78b5UL, "OutputSamplingFrequency", Float, 4, Optional, Some(audio_id)),
  spec(0x9fUL, "Channels", Unsigned, 4, Required, Some(audio_id)),
  spec(0x6264UL, "BitDepth", Unsigned, 4, Optional, Some(audio_id)),

  // Cluster and block metadata.
  spec(0xe7UL, "Timecode", Unsigned, 2, Required, Some(cluster_id)),
  spec(0xa7UL, "Position", Unsigned, 2, Optional, Some(cluster_id)),
  spec(0xabUL, "PrevSize", Unsigned, 2, Optional, Some(cluster_id)),
  spec(0xa3UL, "SimpleBlock", Binary, 2, Repeated, Some(cluster_id)),
  spec(block_group_id, "BlockGroup", Master, 2, Repeated, Some(cluster_id)),
  spec(0xafUL, "EncryptedBlock", Binary, 2, Repeated, Some(cluster_id)),
  spec(0xa1UL, "Block", Binary, 3, Required, Some(block_group_id)),
  spec(0x9bUL, "BlockDuration", Unsigned, 3, Optional, Some(block_group_id)),
  spec(0xfbUL, "ReferenceBlock", Signed, 3, Repeated, Some(block_group_id)),
  spec(0x75a2UL, "DiscardPadding", Signed, 3, Optional, Some(block_group_id)),

  // Cue index.
  spec(cue_point_id, "CuePoint", Master, 2, Repeated, Some(cues_id)),
  spec(0xb3UL, "CueTime", Unsigned, 3, Required, Some(cue_point_id)),
  spec(
    cue_track_positions_id,
    "CueTrackPositions",
    Master,
    3,
    Repeated,
    Some(cue_point_id),
  ),
  spec(0xf7UL, "CueTrack", Unsigned, 4, Required, Some(cue_track_positions_id)),
  spec(
    0xf1UL,
    "CueClusterPosition",
    Unsigned,
    4,
    Required,
    Some(cue_track_positions_id),
  ),
  spec(
    0xf0UL,
    "CueRelativePosition",
    Unsigned,
    4,
    Optional,
    Some(cue_track_positions_id),
  ),
  spec(
    0xb2UL,
    "CueDuration",
    Unsigned,
    4,
    Optional,
    Some(cue_track_positions_id),
  ),
]
