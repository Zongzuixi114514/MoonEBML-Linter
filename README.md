# MoonEBML Linter

MoonBit tools for inspecting and validating Matroska/WebM containers.

The first increment implements the EBML variable-size integer decoder. Higher
layers will be added one feature at a time after each increment has a passing
test suite.

## Development

```text
moon test
moon fmt
moon info
```

The repository deliberately uses parsing-stage packages (`wire/ebml`,
`container/matroska`, and later `checks` and `tools`) instead of a facade/core
layout.
