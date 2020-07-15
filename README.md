# PDFInfo

![Actions Status](https://github.com/preciz/pdf_info/workflows/test/badge.svg)

Extracts all /Info and /Metadata objects from a PDF binary using Regex
and without any external dependencies.

## Installation

Add `pdf_info` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pdf_info, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
iex(1)> pdf = File.read!("/Downloads/sample.pdf")
<<37, 80, 68, 70, 45, ...>>
iex(2)> PDFInfo.is_pdf?(pdf)
true # looks like it's a PDF!
iex(3)> PDFInfo.is_encrypted?(pdf)
false # it's not encrypted (this lib can't decrypt, if it's encrypted then decrypt first)
iex(4)> PDFInfo.info_objects(pdf)
# a map with info objects
%{"/Info 6 0 R" => [
  %{
  "Author" => "Barna Kovacs",
  "CreationDate" => "D:20200212212756Z",
  "Title" => "Can't come up with a title"
  }
]}
iex(5)> PDFInfo.metadata_objects(pdf)
# list of maps with metadata
[
  %{
    {"dc", "creator"} => "Barna Kovacs",
    {"dc", "format"} => "application/pdf",
    {"dc", "title"} => "Can't come up with a title",
    ...
  }
]

```

## Documentation

Documentation can be be found at [https://hexdocs.pm/pdf_info](https://hexdocs.pm/pdf_info).

## License

PDFInfo is [MIT licensed](LICENSE).

## Credit

Inspired by [https://gitlab.com/nxl4/pdf-metadata](https://gitlab.com/nxl4/pdf-metadata)
