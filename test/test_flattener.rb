require_relative './util'
require 'minitest/autorun'
require 'json'
require 'argot'

class ArgotFlattenerTest < Minitest::Test
  def test_process_file
    good = Util.get_file("argot-allgood.json")
    doc = JSON.parse(good.read)
    recs = []
    recs << Argot::Flattener.process(doc)

    assert "'good' test file should have one record", recs.length == 1
    rec = recs[0]
    assert_equal rec['authors_other_vernacular_lang'][0],  "ru"
  end

  def test_misc_id_flattener
    misc_id = Util.get_file("argot-misc-id-flattener.json")
    doc = JSON.parse(misc_id.read)
    recs = []
    recs << Argot::Flattener.process(doc, {'misc_id' => {'flattener' => 'misc_id'}})
    rec = recs[0]
    assert_equal rec['misc_id'],
                 ["LCCN: 86752311",
                  "NUCMC: 13947215",
                  "LCCN: 70001437 //r84",
                  "LCCN (canceled or invalid): 77373485",
                  "National Bibliography Number: GB96-439",
                  "British national bibliography: GB7205212 (v. 2)",
                  "National Bibliography Number: 20023012390 (pbk.)",
                  "National Bibliography Number: BBM68-3648",
                  "National Bibliography Number: LACAP68-3222",
                  "International Standard Music Number: M011406601",
                  "International Standard Music Number: M011406605 (bananas)",
                  "Canadian Geographical Names Database: M500246596 (sewn)",
                  "International Standard Music Number: M001124089",
                  "International Standard Music Number (canceled or invalid): M001124083",
                  "Unspecified Standard Number: alfredelizabethbrandcolcivilwarleefamily DUKEPLEAD",
                  "Technical Report Number: EDO-CE-00-222",
                  "Technical Report Number (canceled or invalid): EDO-CE-00-333",
                  "Video Publisher Number: MAG100 (Criterion Collection)",
                  "CODEN designation: PASPFZ",
                  "GPO Item Number: 1023-A (online)",
                  "GPO Item Number: 1023-B (microfiche)",
                  "Report Number: Serial no. 107-25 (United States. Congress. House. Committee on Financial Services)"]
    assert_equal rec['misc_id_indexed'],
                 ["86752311",
                  "13947215",
                  "70001437 //r84",
                  "77373485",
                  "GB96-439",
                  "GB7205212",
                  "20023012390",
                  "BBM68-3648",
                  "LACAP68-3222",
                  "M011406601",
                  "M011406605",
                  "M500246596",
                  "M001124089",
                  "M001124083",
                  "alfredelizabethbrandcolcivilwarleefamily DUKEPLEAD",
                  "EDO-CE-00-222",
                  "EDO-CE-00-333",
                  "MAG100",
                  "MAG100",
                  "PASPFZ",
                  "1023-A",
                  "1023-B",
                  "Serial no. 107-25 (United States. Congress. House. Committee on Financial Services)"]
  end

  def test_note_flattener
    note = Util.get_file("argot-note-flattener.json")
    doc = JSON.parse(note.read)
    recs = []
    recs << Argot::Flattener.process(doc, {'note_performer_credits' => {'flattener' => 'note'}})

    rec = recs[0]
    assert_equal rec['note_performer_credits'],
                 ["Cast: Ronald Colman, Elizabeth Allan, Edna May Oliver.",
                  "This should be displayed only",
                  "This should be displayed only, too"]
    assert_equal rec['note_performer_credits_indexed'],
                    ["Ronald Colman, Elizabeth Allan, Edna May Oliver.",
                    "This should be indexed instead"]
  end

  def test_title_variant_flattener
    title_variant = Util.get_file("argot-title-variant-flattener.json")
    doc = JSON.parse(title_variant.read)
    recs = []
    recs << Argot::Flattener.process(doc, {'title_variant' => {'flattener' => 'title_variant'}})

    rec = recs[0]
    assert_equal rec['title_abbrev_indexed'],
                 ['GATT act.',
                  'New-England j. med. surg. collat. branches sci.']
    assert_equal rec['title_key_indexed'],
                 'advocate of peace and universal brotherhood (Online)'
    assert_equal rec['title_variant'],
                 ['Spine title: Cicero\'s epistles',
                  'Title varies: Academic science and engineering. R&D expenditures 1990-',
                  'Title on t.p. verso: Bright ray of hope',
                  'ARBA [serial].',
                  'Added title page title: Book 3: Onuphrij Panuinij Veronensis '\
                  'Fratris Eremitae Augustiniani Imperium Romanum',
                  'Added title page title: Book 2: Onuphrij Panuinij Veronensis '\
                  'Fratris Eremitae Augustiniani Ciuitas Romana']
    assert_equal rec['title_variant_indexed'],
                 ['Early Russian architecture',
                  'Architecture de la vieille Russie',
                  'Altrussische Baukunst',
                  'Arquitectura de la antigua Rus',
                  'Revista do Instituto Historico e Geographico Brazileiro',
                  'Cicero\'s epistles',
                  'Academic science and engineering. R&D expenditures',
                  'Bright ray of hope',
                  'ARBA',
                  'Onuphrij Panuinij Veronensis Fratris Eremitae Augustiniani Imperium Romanum',
                  'Onuphrij Panuinij Veronensis Fratris Eremitae Augustiniani Ciuitas Romana',
                  'Loving pretty women',
                  'GATT activities']
    assert_equal rec['title_former'],
                 ['1840-42: Lowell offering : a repository of original articles, written exclusively by females '\
                  'actively employed in the mills (title varies slightly)',
                  'v. 3-24, no. 3, 1987-2009: Labor lawyer. ISSN: 8756-2995']
    assert_equal rec['title_former_indexed'],
                 ['Lowell offering : a repository of original articles, written exclusively by females actively '\
                  'employed in the mills',
                  'Labor lawyer',
                  'Anales de las Reales Junta de Fomento y Sociedad Económica de la Habana']
    assert_equal rec['title_former_issn'], '8756-2995'
  end
end
