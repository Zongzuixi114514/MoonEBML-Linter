# MoonEBML Linter

MoonBit tools for inspecting and validating Matroska/WebM containers.

The first increments implement EBML wire primitives: variable-size integer
decoding, element-header reading, zero-copy payload views, a bounded element
walker, scalar value decoding, and a table-driven schema catalog. Higher layers
will be added one feature at a time after each increment has a passing test
suite.

## Development

```text
moon test
moon fmt
moon info
```

The repository deliberately uses parsing-stage packages (`wire/ebml`,
`container/matroska`, and later `checks` and `tools`) instead of a facade/core
layout.
