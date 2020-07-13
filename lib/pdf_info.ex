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
    |> Enum.reduce(%{}, fn {meta_ref, list}, acc ->
      Map.put(acc, meta_ref, Enum.map(list, &parse_metadata_object/1))
    end)
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

      get_object(binary, obj_id)
      |> case do
        [] ->
          Map.put(acc, info_ref, [])

        list when is_list(list) ->
          list = list |> Enum.flat_map(& &1) |> Enum.uniq()

          Map.put(acc, info_ref, list)
      end
    end)
  end

  @doc """
  Maps the /Metadata reference strings to the raw objects.

  ## Examples

      iex> PDFInfo.raw_metadata_objects(binary)
      %{"/Metadata 5 0 R" => ["5 0 obj\..."]}

  """
  @spec raw_metadata_objects(binary) :: map
  def raw_metadata_objects(binary) when is_binary(binary) do
    binary
    |> metadata_refs()
    |> Enum.reduce(%{}, fn meta_ref, acc ->
      obj_id =
        meta_ref
        |> String.trim_leading("/Metadata ")
        |> String.trim_trailing(" R")

      get_object(binary, obj_id)
      |> case do
        [] ->
          Map.put(acc, meta_ref, [])

        list when is_list(list) ->
          list = list |> Enum.flat_map(& &1) |> Enum.uniq()

          Map.put(acc, meta_ref, list)
      end
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
      Regex.scan(~r{/([^ /]+)\s*<(.*?)>}, string)
      |> Enum.map(fn
        [_, key, val] -> {key, val}
      end)
      |> Enum.reduce([], fn
        {key, "feff" <> base_16_encoded_utf16_big_endian}, acc ->
          base_16_encoded_utf16_big_endian
          |> String.replace(~r{[^0-9a-f]}, "")
          |> Base.decode16(case: :lower)
          |> case do
            {:ok, ut16_binary} ->
              string = :unicode.characters_to_binary(ut16_binary, {:utf16, :big})

              [{key, string} | acc]

            :error ->
              acc
          end

        {key, val}, acc ->
          [{key, val} | acc]
      end)

    Enum.concat(strings, hex)
    |> Map.new()
  end

  @doc false
  def parse_metadata_object(string) when is_binary(string) do
    with [xmp] <- Regex.run(~r{<x:xmpmeta.*?</x:xmpmeta}sm, string) do
      dc_list = Regex.scan(~r{<dc:(.*?)>(.*?)</dc:(.*?)>}, xmp)
      pdf_list = Regex.scan(~r{<pdf:(.*?)>(.*?)</pdf:(.*?)>}, xmp)
      xmp_list = Regex.scan(~r{<xmp:(.*?)>(.*?)</xmp:(.*?)>}, xmp)
      xmp_mm_list = Regex.scan(~r{<xmpMM:(.*?)>(.*?)</xmpMM:(.*?)>}, xmp)

      %{}
      |> reduce_metadata("dc", dc_list)
      |> reduce_metadata("pdf", pdf_list)
      |> reduce_metadata("xmp", xmp_list)
      |> reduce_metadata("xmpMM", xmp_mm_list)
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
        [_, key, val, key], acc -> Map.put(acc, {type, key}, val)
        _, acc -> acc
      end
    )
  end

  @doc false
  def get_object(binary, obj_id) when is_binary(binary) and is_binary(obj_id) do
    ~r{[^0-9](#{obj_id}\sobj.*?endobj)}s
    |> Regex.scan(binary)
    |> Enum.map(fn
      [_, obj] -> [obj]
    end)
  end
end
