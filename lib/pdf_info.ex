defmodule PDFInfo do
  @moduledoc """
  The goal of PDFInfo is to extract all metadata from a PDF binary without any external dependencies.
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
  @spec version(binary) :: {:ok, binary} | :error
  def version(<<"%PDF-">> <> <<version :: binary-size(3)>> <> _) do
    {:ok, version}
  end

  def version(_) do
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
  @spec encrypted?(binary) :: boolean
  def encrypted?(binary) when is_binary(binary) do
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
  Maps the /Info reference strings to objects.

  Example:

      %{
        "/Info 1 0 R" => ["\n1 0 obj\n<<..."]
      }
  """
  @spec info_objects(binary) :: map
  def info_objects(binary) when is_binary(binary) do
    binary
    |> info_refs()
    |> Enum.reduce(%{}, fn info_ref, acc ->
      obj_id =
        info_ref
        |> String.trim_leading("/Info ")
        |> String.trim_trailing(" R")

      ~r{[^0-9]#{obj_id}\sobj.*?endobj}s
      |> Regex.scan(binary)
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
  Maps the /Metadata reference strings to objects.

  Example:

      %{
        "/Metadata 5 0 R" => ["\n5 0 obj\..."]
      }
  """
  @spec metadata_objects(binary) :: map
  def metadata_objects(binary) when is_binary(binary) do
    binary
    |> metadata_refs()
    |> Enum.reduce(%{}, fn meta_ref, acc ->
      obj_id =
        meta_ref
        |> String.trim_leading("/Metadata ")
        |> String.trim_trailing(" R")

      ~r{[^0-9]#{obj_id}\sobj.*?endobj}s
      |> Regex.scan(binary)
      |> case do
        [] ->
          Map.put(acc, meta_ref, [])

        list when is_list(list) ->
          list = list |> Enum.flat_map(& &1) |> Enum.uniq()

          Map.put(acc, meta_ref, list)
      end
    end)
  end
end
