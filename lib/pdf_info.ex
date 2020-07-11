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

  Example:

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

  Example:

      ["/Metadata 5 0 R"]
  """
  @spec metadata_refs(binary) :: list
  def metadata_refs(binary) when is_binary(binary) do
    Regex.scan(~r{[/]Metadata[\s0-9]*?R}, binary)
    |> Enum.flat_map(& &1)
    |> Enum.uniq()
  end

  @doc """
  Maps and parses the /Info reference strings.

  Example:

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
    |> raw_info_objects
    |> Enum.reduce(%{}, fn {info_ref, list}, acc ->
      Map.put(acc, info_ref, Enum.map(list, &parse_info_object/1))
    end)
  end

  @doc """
  Maps the /Info reference strings to the raw objects.

  Example:

      %{
        "/Info 1 0 R" => ["\n1 0 obj\n<<..."]
      }
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

  Example:

      %{
        "/Metadata 5 0 R" => ["\n5 0 obj\..."]
      }
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
    Regex.scan(~r{/(.*?)\s.*?\((.*?)\)}, string)
    |> Enum.map(fn
      [_, key, val] -> {key, val}
    end)
    |> Map.new()
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
