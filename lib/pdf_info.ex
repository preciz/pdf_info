defmodule PDFInfo do
  @moduledoc """
  Extracts all /Info and /Metadata objects from a PDF binary using Regex
  and without any external dependencies.
  """

  @doc """
  Checks if the binary starts with the PDF header.

  Returns `true` if the binary starts with the PDF header.
  Returns `false` otherwise.
  """
  @spec is_pdf?(binary) :: boolean
  def is_pdf?(<<"%PDF">> <> _), do: true

  def is_pdf?(_), do: false

  @doc """
  Extracts PDF version from the PDF header.

  Returns `{:ok, version}` if the PDF header is correct.
  Returns `:error` if the PDF header is incorrect.

  ## Examples

      iex> PDFInfo.pdf_version(binary)
      {:ok, "1.5"}
      iex> PDFInfo.pdf_version("not a pdf")
      :error

  """
  @spec pdf_version(binary) :: {:ok, binary} | :error
  def pdf_version(<<"%PDF-">> <> <<version::binary-size(3)>> <> _) do
    {:ok, version}
  end

  def pdf_version(_) do
    :error
  end

  @doc """
  Returns a list of /Encrypt reference strings.

  ## Examples

      iex> PDFInfo.encrypt_refs(binary)
      ["/Encrypt 52 0 R"]

  """
  @spec encrypt_refs(binary) :: list
  def encrypt_refs(binary) when is_binary(binary) do
    Regex.scan(~r{[/]Encrypt[ ]*[0-9].*?R}, binary)
    |> Enum.flat_map(& &1)
    |> Enum.uniq()
  end

  @doc """
  Returns `true` if PDF has at least one /Encrypt reference.
  Returns `false` if PDF has no /Encrypt reference.
  """
  @spec is_encrypted?(binary) :: boolean
  def is_encrypted?(binary) when is_binary(binary) do
    case encrypt_refs(binary) do
      [] -> false
      _ -> true
    end
  end

  @doc """
  Returns a list of /Info reference strings.

  ## Examples

      iex> PDFInfo.info_refs(binary)
      ["/Info 1 0 R"]

  """
  @spec info_refs(binary) :: list
  def info_refs(binary) when is_binary(binary) do
    Regex.scan(~r{[/]Info[\s0-9]*?R}, binary)
    |> Enum.flat_map(& &1)
    |> Enum.uniq()
  end

  @doc """
  Returns a list of /Metadata reference strings.

  ## Examples

      iex> PDFInfo.metadata_refs(binary)
      ["/Metadata 5 0 R"]

  """
  @spec metadata_refs(binary) :: list
  def metadata_refs(binary) when is_binary(binary) do
    Regex.scan(~r{[/]Metadata[\s0-9]*?R}, binary)
    |> Enum.flat_map(& &1)
    |> Enum.uniq()
  end

  @doc """
  Maps /Info reference strings to objects and parses the objects.

  ## Examples

      iex> PDFInfo.info_objects(binary)
      %{
        "/Info 1 0 R" => [
            %{
                "Author" => "The PostgreSQL Global Development Group",
                "CreationDate" => "D:20200212212756Z",
                ...
            }
        ]
      }

  """
  @spec info_objects(binary) :: map
  def info_objects(binary) when is_binary(binary) do
    binary
    |> raw_info_objects()
    |> Enum.reduce(%{}, fn {info_ref, list}, acc ->
      Map.put(acc, info_ref, Enum.map(list, &parse_info_object/1))
    end)
  end

  @doc """
  Maps /Metadata reference strings to objects and parses the objects.

  ## Examples

      iex> PDFInfo.metadata_objects(binary)
      %{
          "/Metadata 285 0 R" => [
            %{
              {"dc", "format"} => "application/pdf",
              {"pdf", "Producer"} => "Adobe PDF Library 15.0",
              {"xmp", "CreateDate"} => "2018-06-06T17:02:53+02:00",
              {"xmp", "CreatorTool"} => "Acrobat PDFMaker 17 für Word",
              {"xmp", "MetadataDate"} => "2018-06-06T17:03:13+02:00",
              {"xmp", "ModifyDate"} => "2018-06-06T17:03:13+02:00",
              ...
            }
          ]
      }

  """
  @spec metadata_objects(binary) :: map
  def metadata_objects(binary) when is_binary(binary) do
    binary
    |> raw_metadata_objects()
    |> Enum.map(&parse_metadata_object/1)
  end

  @doc """
  Maps the /Info reference strings to the raw objects.

  ## Examples

      iex> PDFInfo.raw_info_objects(binary)
      %{"/Info 1 0 R" => ["1 0 obj <<..."]}

  """
  @spec raw_info_objects(binary) :: map
  def raw_info_objects(binary) when is_binary(binary) do
    binary
    |> info_refs()
    |> Enum.reduce(%{}, fn info_ref, acc ->
      obj_id =
        info_ref
        |> String.trim_leading("/Info ")
        |> String.trim_trailing(" R")

      list =
        get_object(binary, obj_id)
        |> Enum.flat_map(& &1)
        |> Enum.uniq()

      Map.put(acc, info_ref, list)
    end)
  end

  @doc """
  Maps the /Metadata reference strings to the raw objects.

  ## Examples

      iex> PDFInfo.raw_metadata_objects(binary)
      ["<x:xmpmeta" <> ...]

  """
  @spec raw_metadata_objects(binary) :: list
  def raw_metadata_objects(binary) when is_binary(binary) do
    Enum.zip(
      Regex.scan(~r{<x:xmpmeta}, binary, return: :index),
      Regex.scan(~r{</x:xmpmeta}, binary, return: :index)
    )
    |> Enum.reduce([], fn
      {[{start_position, _}], [{end_position, _}]}, acc when start_position < end_position ->
        raw_meta =
          binary_part(binary, start_position, end_position - start_position) <> "</x:xmpmeta>"

        [raw_meta | acc]

      _, acc ->
        acc
    end)
  end

  @doc false
  def parse_info_object(string) when is_binary(string) do
    strings =
      Regex.scan(~r{/(.*?)\s*\((.*?)\)}, string)
      |> Enum.map(fn
        [_, key, val] -> {key, val}
      end)

    hex =
      Regex.scan(~r{/([^ /]+)\s*<(.*?)>}s, string)
      |> Enum.map(fn
        [_, key, val] -> {key, val}
      end)

    Enum.concat(strings, hex)
    |> Enum.reduce([], fn
      {key, "feff" <> base_16_encoded_utf16_big_endian}, acc ->
        base_16_encoded_utf16_big_endian
        |> String.replace(~r{[^0-9a-f]}, "")
        |> Base.decode16(case: :lower)
        |> case do
          {:ok, utf16} ->
            endianness = determine_endianness(utf16, :big)

            utf16 = utf16_size_fix(utf16)

            string = :unicode.characters_to_binary(utf16, {:utf16, endianness})

            [{key, string} | acc]

          :error ->
            acc
        end

      {key, <<254, 255>> <> utf16}, acc ->
        endianness = determine_endianness(utf16, :big)

        utf16 = utf16_size_fix(utf16)

        string = :unicode.characters_to_binary(utf16, {:utf16, endianness})

        [{key, string} | acc]

      {key, "\\376\\377" <> rest}, acc ->
        # Fix metadata: https://github.com/mozilla/pdf.js/pull/1598/files#diff-7f3b58adf9e7b7e802f63cc9b3855506R7

        [{key, fix_null_padded_utf16(rest)} | acc]

      {key, val}, acc ->
        [{key, val} | acc]
    end)
    |> Enum.map(fn {key, val} ->
      {
        key,
        case String.printable?(val) do
          false ->
            # Fix for non printable binary like <<252>> = ü
            val |> :binary.bin_to_list() |> :unicode.characters_to_binary()

          true ->
            val
        end
      }
    end)
    |> Map.new()
  end

  @doc false
  @spec fix_null_padded_utf16(binary) :: binary
  def fix_null_padded_utf16(binary) when is_binary(binary) do
    string = fix_null_padding(binary)

    endianness = string |> determine_endianness(:big)

    :unicode.characters_to_binary(string, {:utf16, endianness})
  end

  @doc false
  def utf16_size_fix(binary) do
    case rem(byte_size(binary), 2) do
      0 -> binary
      1 -> binary <> <<0>>
    end
  end

  @doc false
  def fix_null_padding(binary) do
    fix_null_padding(binary, "")
  end

  def fix_null_padding(<<>>, acc) do
    acc
  end

  @d1_digits Enum.map(0..3, &to_string/1)
  @d2_and_d3_digits Enum.map(0..7, &to_string/1)

  def fix_null_padding(
        "\\" <> <<d1::bytes-size(1)>> <> <<d2::bytes-size(1)>> <> <<d3::bytes-size(1)>> <> rest,
        acc
      )
      when d1 in @d1_digits and d2 in @d2_and_d3_digits and d3 in @d2_and_d3_digits do
    code = String.to_integer(d1) * 64 + String.to_integer(d2) * 8 + String.to_integer(d3) * 1

    fix_null_padding(rest, acc <> <<code::utf8>>)
  end

  def fix_null_padding(<<byte::bytes-size(1)>> <> rest, acc) do
    fix_null_padding(rest, acc <> byte)
  end

  @doc false
  def parse_metadata_object(string) when is_binary(string) do
    with [xmp] <- Regex.run(~r{<x:xmpmeta.*?</x:xmpmeta}sm, string) do
      ["dc", "pdf", "pdfx", "xap", "xapMM", "xmp", "xmpMM"]
      |> Enum.reduce(%{}, fn tag, acc ->
        list = Regex.scan(~r{<#{tag}:(.*?)>(.*?)</#{tag}:(.*?)>}sm, xmp)

        reduce_metadata(acc, tag, list)
      end)
    else
      _ -> :error
    end
  end

  @doc false
  def reduce_metadata(acc, type, list) do
    list
    |> Enum.reduce(
      acc,
      fn
        [_, key, val, key], acc ->
          # remove rdf tags like <rdf:Alt>, </rdf:Alt>, <rdf:li ... />
          val =
            val
            |> String.replace(~r{<[a-z]+:[a-z]+>}i, " ")
            |> String.replace(~r{</[a-z]+:[a-z]+>}i, " ")
            |> String.replace(~r{<[a-z]+:.+/>}i, " ")
            |> String.trim()

          Map.put(acc, {type, key}, val)

        _, acc ->
          acc
      end
    )
  end

  @doc false
  def get_object(binary, obj_id) when is_binary(binary) and is_binary(obj_id) do
    obj_id = String.replace(obj_id, " ", "\s")

    ~r{[^0-9]#{obj_id}.obj(?s).*?endobj}
    |> Regex.scan(binary)
  end

  # it can have messed up byte order marker
  @doc false
  def determine_endianness(binary, initial_guess) do
    determine_endianness(binary, initial_guess, 0, 0)
  end

  defp determine_endianness(<<>>, _, little_zeros, big_zeros) do
    case {little_zeros, big_zeros} do
      {lz, bz} when lz > bz -> :little
      {lz, bz} when bz >= lz -> :big
    end
  end

  defp determine_endianness(<<0>> <> binary, :little, little_zeros, big_zeros) do
    determine_endianness(binary, :big, little_zeros + 1, big_zeros)
  end

  defp determine_endianness(<<0>> <> binary, :big, little_zeros, big_zeros) do
    determine_endianness(binary, :little, little_zeros, big_zeros + 1)
  end

  defp determine_endianness(<<_>> <> binary, :little, little_zeros, big_zeros) do
    determine_endianness(binary, :big, little_zeros, big_zeros)
  end

  defp determine_endianness(<<_>> <> binary, :big, little_zeros, big_zeros) do
    determine_endianness(binary, :little, little_zeros, big_zeros)
  end
end
