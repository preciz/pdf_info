defmodule PDFInfo.MixProject do
  use Mix.Project

  @version "0.1.17"
  @github "https://github.com/preciz/pdf_info"

  def project do
    [
      app: :pdf_info,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description:
        "Extracts all /Info and /Metadata objects from a PDF binary using Regex and with zero dependencies.",
      # Docs
      name: "PDFInfo",
      docs: docs()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Barna Kovacs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @github}
    ]
  end

  defp docs do
    [
      main: "PDFInfo",
      source_ref: "v#{@version}",
      source_url: @github
    ]
  end
end
