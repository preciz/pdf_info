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

  test "Parses /Info object with hex values" do
    binary = """
    trailer<</Size 50/Root 31 0 R/Info 29 0 R/ID[<9E8E7E331ECF4031AC5612D8279F65B1><7DA167C2B63942E59AA17FCA1C9587CF>]/Prev 486980>>startxref0%%EOF                  49 0 obj<</Filter/FlateDecode/I 227/L 211/Length 188/S 129/V 189>>stream
    hÞb```"OGFA±1Ç/?é¶q×g	½Ú{fÎ	VÀT9áRÔ²H9£éF'>*NÙ9Í½géM6©:@ùFÁ £H 3

    29 0 obj\r<<\r/CreationDate (D:20191125152027+01'00')\r/Creator (Adobe InDesign CC 13.1 \\(Macintosh\\))\r/ModDate (D:20191202125216)\r/Producer (Adobe PDF Library 15.0)\r/Trapped /False\r/Author <feff005300740061006400740020004e00fc0072006e00620065007200670020002f002000500072\r0065007300730065002d00200075006e006400200049006e0066006f0072006d006100740069006f\r006e00730061006d0074>\r/Keywords <feff006e00fc0072006e00620065007200670020006800650075007400650020003100300037002c\r0020006d00610064006500200069006e0020006e00fc0072006e0062006500720067002c0020004d\r0061006d004f0062006a0065006b0074>\r/Subject <feff004c006900650062006c0069006e006700730073007400fc0063006b00650020006d00610064\r006500200069006e0020004e00fc0072006e0062006500720067002e>\r/Title <feff004e006800200031003000370020004c006900650062006c0069006e00670073007400fc0063\r006b0065>\r>>\rendobj
    """

    assert PDFInfo.info_objects(binary) == %{
             "/Info 29 0 R" => [
               %{
                 "Author" => "Stadt Nürnberg / Presse- und Informationsamt",
                 "CreationDate" => "D:20191125152027+01'00'",
                 "Creator" => "Adobe InDesign CC 13.1 \\(Macintosh\\",
                 "Keywords" => "nürnberg heute 107, made in nürnberg, MamObjekt",
                 "ModDate" => "D:20191202125216",
                 "Producer" => "Adobe PDF Library 15.0",
                 "Subject" => "Lieblingsstücke made in Nürnberg.",
                 "Title" => "Nh 107 Lieblingstücke"
               }
             ]
           }

    binary =
      "\r5 0 obj\r<<\r/CreationDate (D:20180511175759+02'00')\r/Creator (Adobe InDesign CS6 \\(Macintosh\\))\r/ModDate (D:20181130123617)\r/Producer (Adobe PDF Library 10.0.1)\r/Trapped /False\r/Author (Project AG)\r/Keywords <417263686974656b747572707265697320323031380a456e67657265205761686c0a4d45494e2054\r484f4e2c204d616d4f626a656b74>\r/Subject <456e67657265205761686c0a4d45494e2054484f4e>\r/Title (Plakat)\r>>\rendobj"

    assert PDFInfo.parse_info_object(binary) == %{
             "Title" => "Plakat",
             "Author" => "Project AG",
             "CreationDate" => "D:20180511175759+02'00'",
             "Creator" => "Adobe InDesign CS6 \\(Macintosh\\",
             "Keywords" => "Architekturpreis 2018\nEngere Wahl\nMEIN THON, MamObjekt",
             "ModDate" => "D:20181130123617",
             "Producer" => "Adobe PDF Library 10.0.1",
             "Subject" => "Engere Wahl\nMEIN THON"
           }
  end

  test "Extracts raw /Metadata object" do
    assert ["<x:xmpmeta" <> _ | _] = PDFInfo.raw_metadata_objects(@metadata_binary)
  end

  test "Parses /Info non-hex utf16 and corrects endianness" do
    binary =
      <<51, 32, 48, 32, 111, 98, 106, 10, 60, 60, 47, 67, 114, 101, 97, 116, 111, 114, 40, 81,
        117, 97, 114, 107, 88, 80, 114, 101, 115, 115, 92, 40, 82, 92, 41, 32, 49, 52, 46, 48, 49,
        41, 47, 88, 80, 114, 101, 115, 115, 80, 114, 105, 118, 97, 116, 101, 40, 37, 37, 68, 111,
        99, 117, 109, 101, 110, 116, 80, 114, 111, 99, 101, 115, 115, 67, 111, 108, 111, 114, 115,
        58, 32, 67, 121, 97, 110, 32, 77, 97, 103, 101, 110, 116, 97, 32, 89, 101, 108, 108, 111,
        119, 32, 66, 108, 97, 99, 107, 92, 48, 49, 50, 37, 37, 69, 110, 100, 67, 111, 109, 109,
        101, 110, 116, 115, 41, 47, 84, 105, 116, 108, 101, 40, 254, 255, 0, 50, 0, 48, 0, 83, 0,
        101, 0, 105, 0, 116, 0, 101, 0, 110, 41, 47, 67, 114, 101, 97, 116, 105, 111, 110, 68, 97,
        116, 101, 40, 68, 58, 50, 48, 49, 57, 48, 52, 50, 51, 49, 52, 52, 51, 52, 57, 43, 48, 49,
        39, 48, 48, 39, 41, 47, 80, 114, 111, 100, 117, 99, 101, 114, 40, 81, 117, 97, 114, 107,
        88, 80, 114, 101, 115, 115, 92, 40, 82, 92, 41, 32, 49, 52, 46, 48, 49, 41, 47, 65, 117,
        116, 104, 111, 114, 40, 254, 255, 65, 0, 110, 0, 100, 0, 114, 0, 101, 0, 97, 0, 115, 0,
        32, 0, 72, 0, 246, 0, 110, 0, 105, 0, 103, 0, 41, 47, 77, 111, 100, 68, 97, 116, 101, 40,
        68, 58, 50, 48, 49, 57, 48, 52, 50, 51, 49, 52, 52, 51, 52, 57, 43, 48, 49, 39, 48, 48,
        39, 41, 62, 62, 10, 101, 110, 100, 111, 98, 106>>

    assert PDFInfo.parse_info_object(binary) == %{
             "Author" => "Andreas Hönig",
             "CreationDate" => "D:20190423144349+01'00'",
             "Creator" => "QuarkXPress\\(R\\",
             "ModDate" => "D:20190423144349+01'00'",
             "Producer" => "QuarkXPress\\(R\\",
             "Title" => "20Seiten",
             "XPressPrivate" =>
               "%%DocumentProcessColors: Cyan Magenta Yellow Black\n%%EndComments"
           }
  end

  test "Parses /Metadata object" do
    assert PDFInfo.metadata_objects(@metadata_binary) == [
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
  end

  test "Parses metadata with <xap> tags and removed <rdf> tags from parsed values" do
    binary = """
    /Metadata 13 0 R\" => [\"13 0 obj\n<</Type/Metadata\n/Subtype/XML/Length 1378>>stream\n<?xpacket begin='\uFEFF' id='W5M0MpCehiHzreSzNTczkc9d'?>\n<?adobe-xap-filters esc=\"CRLF\"?>\n<x:xmpmeta xmlns:x='adobe:ns:meta/' x:xmptk='XMP toolkit 2.9.1-13, framework 1.6'>\n<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#' xmlns:iX='http://ns.adobe.com/iX/1.0/'>\n<rdf:Description rdf:about='45b761fe-38d9-11e0-0000-b0e2024cf9b3' xmlns:pdf='http://ns.adobe.com/pdf/1.3/' pdf:Producer='GPL Ghostscript 8.61'/>\n<rdf:Description rdf:about='45b761fe-38d9-11e0-0000-b0e2024cf9b3' xmlns:xap='http://ns.adobe.com/xap/1.0/' xap:ModifyDate='2011-02-12T08:57:26+01:00' xap:CreateDate='2011-02-12T08:57:26+01:00'><xap:CreatorTool>PDFCreator Version 0.9.5</xap:CreatorTool></rdf:Description>\n<rdf:Description rdf:about='45b761fe-38d9-11e0-0000-b0e2024cf9b3' xmlns:xapMM='http://ns.adobe.com/xap/1.0/mm/' xapMM:DocumentID='45b761fe-38d9-11e0-0000-b0e2024cf9b3'/>\n<rdf:Description rdf:about='45b761fe-38d9-11e0-0000-b0e2024cf9b3' xmlns:dc='http://purl.org/dc/elements/1.1/' dc:format='application/pdf'><dc:title><rdf:Alt><rdf:li xml:lang='x-default'>Ganzseitiger Faxausdruck</rdf:li></rdf:Alt></dc:title><dc:creator><rdf:Seq><rdf:li>hjeinwag</rdf:li></rdf:Seq></dc:creator></rdf:Description>\n</rdf:RDF>\n</x:xmpmeta>
    """

    PDFInfo.parse_metadata_object(binary)
  end

  test "Parses metadata with <rdf> tags containing newlines" do
    binary = """
    <?xpacket begin="ï»¿" id="W5M0MpCehiHzreSzNTczkc9d"?>
    <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.6-c148 79.163765, 2019/01/24-18:11:46        ">
       <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about=""
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:pdf="http://ns.adobe.com/pdf/1.3/"
                xmlns:pdfxid="http://www.npes.org/pdfx/ns/id/"
                xmlns:xmp="http://ns.adobe.com/xap/1.0/"
                xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/">
             <dc:creator>
                <rdf:Seq>
                   <rdf:li>from nested</rdf:li>
                </rdf:Seq>
             </dc:creator>
             <dc:title>
                <rdf:Alt>
                   <rdf:li xml:lang="x-default">from nested</rdf:li>
                </rdf:Alt>
             </dc:title>
          </rdf:Description>
       </rdf:RDF>
    </x:xmpmeta>
    <?xpacket end="r"?>
    """

    assert PDFInfo.metadata_objects(binary) == [
             %{{"dc", "creator"} => "from nested", {"dc", "title"} => "from nested"}
           ]
  end

  test "Parses info object if there is a newline after obj" do
    binary = """
    694 0 obj
    <</Type/XRef/Size 694/W[ 1 4 2] /Root 1 0 R/Info 63 0 R/ID[<1EA6838B685AD14F98F5E1E35B0A1E5A><1EA6838B685AD14F98F5E1E35B0A1E5A>] /Filter/FlateDecode/Length 1419>>
    stream

    endobj
    63 0 obj
    <</Author(Bella, Bela)  /ModDate(D:20151214132107+01'00')  >>
    endobj
    70 0 obj
    """

    assert PDFInfo.info_objects(binary) == %{
             "/Info 63 0 R" => [
               %{
                 "Author" => "Bella, Bela",
                 "ModDate" => "D:20151214132107+01'00'"
               }
             ]
           }
  end

  test "Parses info object with null padded utf16 big endian" do
    binary = """
      2 0 obj
      <</Producer(\\376\\377\\000P\\000D\\000F)
      /Author(\\376\\377\\000j\\000s\\000e)>>endobj
    """

    assert PDFInfo.parse_info_object(binary) == %{"Author" => "jse", "Producer" => "PDF"}

    binary2 = """
      \n6 0 obj\n<</Producer(\\376\\377\\000P\\000D\\000F\\000C\\000r\\000e\\000a\\000t\\000o\\000r\\000 \\0002\\000.\\0004\\000.\\0001\\000.\\0001\\0003)\n/CreationDate(D:20190409143940+02'00')\n/ModDate(D:20190409143940+02'00')\n/Title(\\376\\377\\000A\\000n\\000t\\000r\\000a\\000g\\000s\\000f\\000o\\000r\\000m\\000u\\000l\\000a\\000r\\000,\\000 \\000V\\000e\\000r\\000f\\000\\374\\000l\\000l\\000u\\000n\\000g)\n/Author(\\376\\377\\000b\\000k)\n/Subject(\\376\\377)\n/Keywords(\\376\\377)\n/Creator(\\376\\377\\000P\\000D\\000F\\000C\\000r\\000e\\000a\\000t\\000o\\000r\\000 \\0002\\000.\\0004\\000.\\0001\\000.\\0001\\0003)>>endobj
    """

    assert PDFInfo.parse_info_object(binary2) == %{
             "Author" => "bk",
             "Producer" => "PDFCreator 2.4.1.13",
             "CreationDate" => "D:20190409143940+02'00'",
             "Creator" => "PDFCreator 2.4.1.13",
             "Keywords" => "",
             "ModDate" => "D:20190409143940+02'00'",
             "Subject" => "",
             "Title" => "Antragsformular, Verfüllung"
           }
  end

  test "Parsing /Info Corrects encoding issue" do
    binary =
      <<13, 54, 56, 32, 48, 32, 111, 98, 106, 13, 60, 60, 47, 65, 117, 116, 104, 111, 114, 40, 83,
        116, 97, 100, 116, 32, 78, 252, 114, 110, 98, 101, 114, 103, 41, 47, 67, 114, 101, 97,
        116, 105, 111, 110, 68, 97, 116, 101, 40, 68>>

    assert PDFInfo.parse_info_object(binary) == %{"Author" => "Stadt Nürnberg"}
  end

  test "Parsing /Info Transforms octals" do
    binary = """
    \n2 0 obj\n<</Creator( \\256 \\374 )>>endobj
    """

    assert %{"Creator" => " ® ü "} = PDFInfo.parse_info_object(binary)
  end

  test "Parsing /Info fixes octal when leading \\( and trailing \\) is present" do
    binary =
      "\n2 0 obj\n<</Producer(GPL Ghostscript 9.04)\n/CreationDate(D:20151021104825+02'00')\n/ModDate(D:20151021104825+02'00')\n/Title(\\376\\377\\000\\(\\000W\\000o\\000h\\000n\\000u\\000n\\000g\\000s\\000g\\000e\\000b\\000e\\000r\\000b\\000e\\000s\\000t\\000\\344\\000t\\000i\\000g\\000u\\000n\\000g\\000 \\000-\\000 \\000Z\\000u\\000s\\000a\\000t\\000z\\000b\\000l\\000a\\000t\\000t\\000\\))\n/Subject()>>endobj"

    assert %{"Title" => "Wohnungsgeberbestätigung - Zusatzblatt"} =
             PDFInfo.parse_info_object(binary)
  end

  test "Parses /Info object with object references to values" do
    pdf = """
    \n721 0 obj\n(I was referenced)\nendobj
    """

    raw_info_obj = """
    \n1 0 obj\n<< /Title 721 0 R /Author 723 0 R /Subject 724 0 R /Producer 722 0 R /Creator\n725 0 R /CreationDate 726 0 R /ModDate 726 0 R /Keywords 727 0 R /AAPL:Keywords\n728 0 R >>\nendobj
    """

    assert PDFInfo.parse_info_object(raw_info_obj, pdf) == %{"Title" => "I was referenced"}
  end
end
