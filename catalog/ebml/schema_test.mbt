///|
test "look up the EBML header schema" {
  match lookup_element(0x1a45dfa3UL) {
    Some(item) => {
      assert_eq(item.name, "EBML")
      assert_eq(item.kind, Master)
      assert_eq(item.level, 0)
      assert_eq(item.occurrence, Required)
      assert_eq(item.parent_id, None)
    }
    None => fail("expected the EBML schema entry")
  }
}

///|
test "look up scalar and nested Matroska entries" {
  match (lookup_element(0x4489UL), lookup_element(0xb0UL)) {
    (Some(duration), Some(pixel_width)) => {
      assert_eq(duration.name, "Duration")
      assert_eq(duration.kind, Float)
      assert_eq(duration.parent_id, Some(0x1549a966UL))
      assert_eq(pixel_width.name, "PixelWidth")
      assert_eq(pixel_width.kind, Unsigned)
      assert_eq(pixel_width.parent_id, Some(0xe0UL))
    }
    _ => fail("expected known scalar entries")
  }
}

///|
test "unknown identifiers are left to higher-level policy" {
  assert_eq(lookup_element(0xdeadbeefUL), None)
}

///|
test "catalog entries have unique identifiers" {
  let entries = all_elements()
  assert_true(entries.length() > 40)
  for i in 0..<entries.length() {
    for j in (i + 1)..<entries.length() {
      assert_true(entries[i].id != entries[j].id)
    }
  }
  assert_eq(element_count(), entries.length())
}

///|
test "catalog covers the parser dispatch kinds" {
  let entries = all_elements()
  assert_true(entries.any(item => item.kind == Master))
  assert_true(entries.any(item => item.kind == Unsigned))
  assert_true(entries.any(item => item.kind == Signed))
  assert_true(entries.any(item => item.kind == Float))
  assert_true(entries.any(item => item.kind == Utf8))
  assert_true(entries.any(item => item.kind == Binary))
  assert_true(entries.any(item => item.kind == DateUtc))
}
