defmodule PDFInfoTest do
  use ExUnit.Case

  @info_binary """
  trailer
  <<
    /Root 37907 0 R
    /Info 1 0 R
    /ID [<DD4EDCDA157A2F8C5AC9278D8AB4BED7> <DD4EDCDA157A2F8C5AC9278D8AB4BED7>]
    /Size 37910
  >>

  1 0 obj
  <<
  /Title (PostgreSQL 12.2 Documentation)
  /Author (The PostgreSQL Global Development Group)
  /Creator (DocBook XSL Stylesheets with Apache FOP)
  /Producer (Apache FOP Version 2.3)
  /CreationDate (D:20200212212756Z)
  >>
  endobj

  """

  @metadata_binary """
  37907 0 obj
  <<
    /Type /Catalog
    /Pages 11 0 R
    /Lang (en)
    /Metadata 5 0 R
    /PageLabels 37908 0 R
    /Outlines 29900 0 R
    /PageMode /UseOutlines
    /Names 37909 0 R
  >>
  endobj

  endobj
  5 0 obj
  <<
    /Type /Metadata
    /Subtype /XML
    /Length 6 0 R
  >>
  stream
  <?xpacket begin="ï»¿" id="W5M0MpCehiHzreSzNTczkc9d"?><x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/" rdf:about="">
  <dc:creator>The PostgreSQL Global Development Group</dc:creator>
  <dc:format>application/pdf</dc:format>
  <dc:title>PostgreSQL 12.2 Documentation</dc:title>
  <dc:language>en</dc:language>
  <dc:date>2020-02-12T21:27:56Z</dc:date>
  </rdf:Description>
  <rdf:Description xmlns:pdf="http://ns.adobe.com/pdf/1.3/" rdf:about="">
  <pdf:Producer>Apache FOP Version 2.3</pdf:Producer>
  <pdf:PDFVersion>1.4</pdf:PDFVersion>
  </rdf:Description>
  <rdf:Description xmlns:xmp="http://ns.adobe.com/xap/1.0/" rdf:about="">
  <xmp:CreatorTool>DocBook XSL Stylesheets with Apache FOP</xmp:CreatorTool>
  <xmp:MetadataDate>2020-02-12T21:27:56Z</xmp:MetadataDate>
  <xmp:CreateDate>2020-02-12T21:27:56Z</xmp:CreateDate>
  </rdf:Description>
  </rdf:RDF>
  </x:xmpmeta><?xpacket end="r"?>

  endstream
  endobj
  6 0 obj
  976
  """

  test "Recognizes PDF header" do
    assert PDFInfo.is_pdf?("%PDF-1.5\nrandomNoise...")
    refute PDFInfo.is_pdf?("not a pdf")
  end

  test "Parses PDF version" do
    assert PDFInfo.pdf_version("%PDF-1.5\nrandomNoise...") == {:ok, "1.5"}
    assert PDFInfo.pdf_version("not a pdf") == :error
  end

  test "Finds /Encrypt ref" do
    binary = """
      trailer
      <<
         /Root 1 0 R
         /Info 7 0 R
         /Encrypt 52 0 R
         /ID [<1521FBE61419FCAD51878CC5D478D5FF> <1521FBE61419FCAD51878CC5D478D5FF> ]
         /Size 53
      >>
    """

    assert PDFInfo.is_encrypted?(binary)
    refute PDFInfo.is_encrypted?("not a pdf")

    assert PDFInfo.encrypt_refs(binary) == ["/Encrypt 52 0 R"]
    assert PDFInfo.encrypt_refs("not a pdf") == []
  end

  test "Finds /Info ref" do
    assert PDFInfo.info_refs(@info_binary) == ["/Info 1 0 R"]
    assert PDFInfo.info_refs("not a pdf") == []
  end

  test "Finds /Metadata ref" do
    assert PDFInfo.metadata_refs(@metadata_binary) == ["/Metadata 5 0 R"]
    assert PDFInfo.metadata_refs("not a pdf") == []
  end

  test "Parses /Info object" do
    assert PDFInfo.info_objects(@info_binary) == %{
             "/Info 1 0 R" => [
               %{
                 "Author" => "The PostgreSQL Global Development Group",
                 "CreationDate" => "D:20200212212756Z",
                 "Creator" => "DocBook XSL Stylesheets with Apache FOP",
                 "Producer" => "Apache FOP Version 2.3",
                 "Title" => "PostgreSQL 12.2 Documentation"
               }
             ]
           }
  end

  test "Extracts raw /Metadata object" do
    assert %{"/Metadata 5 0 R" => [metadata]} = PDFInfo.raw_metadata_objects(@metadata_binary)
    assert String.starts_with?(metadata, "5 0 obj")
    assert String.ends_with?(metadata, "endobj")
  end

  test "Parses /Metadata object" do
    assert PDFInfo.metadata_objects(@metadata_binary) == %{
             "/Metadata 5 0 R" => [
               %{
                 {"dc", "creator"} => "The PostgreSQL Global Development Group",
                 {"dc", "date"} => "2020-02-12T21:27:56Z",
                 {"dc", "format"} => "application/pdf",
                 {"dc", "language"} => "en",
                 {"dc", "title"} => "PostgreSQL 12.2 Documentation",
                 {"pdf", "PDFVersion"} => "1.4",
                 {"pdf", "Producer"} => "Apache FOP Version 2.3",
                 {"xmp", "CreateDate"} => "2020-02-12T21:27:56Z",
                 {"xmp", "CreatorTool"} => "DocBook XSL Stylesheets with Apache FOP",
                 {"xmp", "MetadataDate"} => "2020-02-12T21:27:56Z"
               }
             ]
           }
  end
end
