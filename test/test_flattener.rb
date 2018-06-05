require_relative './util'
require 'minitest/autorun'
require 'json'
require 'argot'

class ArgotFlattenerTest < Minitest::Test

  def flatten_test_record(argot_file, config = {})
    file = Util.get_file(argot_file)
    doc = JSON.parse(file.read)
    recs = []
    recs << Argot::Flattener.process(doc, config)
    recs
  end

  def test_process_file
    recs = flatten_test_record('argot-allgood.json')
    assert "'good' test file should have one record", recs.length == 1
    rec = recs[0]
    assert_equal rec['authors_other_vernacular_lang'][0],  "ru"
  end

  def test_work_entry_flattener
    config = {'included_work' => {'flattener' => 'work_entry'}}
    rec = flatten_test_record('argot-included-work-flattener.json', config).first
    assert_equal rec['included_author'],
                 ["Saint-Saëns, Camille, 1835-1921.",
                  "Schwenkel, Christina.",
                  "Ferrini, Vincent, 1913-2007.",
                  "Plotinus.",
                  "Name, Author, (Test name), 1944-.",
                  "Kungliga Biblioteket (Sweden).",
                  "United States. Congress (94th, 2nd session : 1976).",
                  "North Carolina. Building Code Council.",
                  "Germany (East).",
                  "Café Tacuba (Musical group)",
                  "Great Central Fair for the U.S. Sanitary Commission (1864 : Philadelphia, Pa.). "\
                  "Committee on Public Charities and Benevolent Institutions.",
                  "Deutsch Foundation Conference (1930 : University of Chicago).",
                  "Masson, VeNeta.",
                  "Masson, VeNeta."]
    assert_equal rec['included_title'],
                 ["Quartets, violins (2), viola, cello, no. 2, op. 153, G major",
                  "Architecture and dwelling in the 'war of destruction' in Vietnam.",
                  "Tidal wave : poems of the great strikes. 1945 (New York : Great-Concord Publishers)",
                  "Peri tou kalou. French (Achard and Narbonne)",
                  "Test title.",
                  "Manuscript. KB787a. Church Slavic. 1966.",
                  "Memorial services held in the House of Representatives and Senate of the United States, together "\
                  "with remarks presented in eulogy of Jerry L. Litton, late a Representative from Missouri. 197.",
                  "North Carolina state building code. 1, General construction. 11X, Making buildings and facilities "\
                  "accessible to and usable by the physically handicapped.",
                  "Treaties, etc. Germany (West), 1990 May 18. 1990.",
                  "12/12",
                  "Philadelphia [blank] 1864. 619 Walnut Street. To [blank] ...",
                  "Care of the aged. 2000, 1972. Reprint.",
                  "Cahiers de civilisation médiévale. Bibliographie.",
                  "Jane Pickering's lute book. arr.",
                  "Drewries Accord's;",
                  "Magnificent Ambersons (Motion picture). Spanish.",
                  "Magnificent Ambersons (Motion picture). English.",
                  "The magnificent Ambersons (Motion picture). English.",
                  "Deutsche Geschichte. Band 6.",
                  "English pilot. The fourth book : describing the West India navigation, "\
                  "from Hudson's-Bay to the river Amazones ...",
                  "The English pilot. The fourth book : describing the West India navigation, "\
                  "from Hudson's-Bay to the river Amazones ...",
                  "Industrial sales management game 5.",
                  "Rehab at the Florida Avenue Grill.",
                  "Rehab at the Florida Avenue Grill.",
                  "Sports illustrated.",
                  "Bulletin (North Carolina Agricultural Experiment Station)",
                  "1991 NC Agricultural Experiment Station Bulletin",
                  "Bellevue literary review :"]
    assert_equal rec['included_isbn'],
                 ["0967368804", "0967368804"]
    assert_equal rec['included_issn'],
                 ["1234-1234", "0240-8678", "1537-5048"]
    assert_equal rec['included_other_ids'],
                 ["99090707",
                  "43689896",
                  "99090707",
                  "43689896",
                  "1766364",
                  "1421220",
                  "2001211888",
                  "48166959"]
    assert_equal rec['included_work_indexed'],
                 ["Saint-Saëns, Camille, 1835-1921. Quartets, violins (2), viola, cello, no. 2, op. 153, G major",
                  "Schwenkel, Christina. Architecture and dwelling in the 'war of destruction' in Vietnam.",
                  "Ferrini, Vincent, 1913-2007. Tidal wave : poems of the great strikes. 1945 "\
                  "(New York : Great-Concord Publishers)",
                  "Plotinus. Peri tou kalou. French (Achard and Narbonne)",
                  "Name, Author, (Test name), 1944-. Test title.",
                  "Kungliga Biblioteket (Sweden). Manuscript. KB787a. Church Slavic. 1966.",
                  "United States. Congress (94th, 2nd session : 1976). Memorial services held in the "\
                  "House of Representatives and Senate of the United States, together with remarks "\
                  "presented in eulogy of Jerry L. Litton, late a Representative from Missouri. 197.",
                  "North Carolina. Building Code Council. North Carolina state building code. 1, General "\
                  "construction. 11X, Making buildings and facilities accessible to and usable by the "\
                  "physically handicapped.",
                  "Germany (East). Treaties, etc. Germany (West), 1990 May 18. 1990.",
                  "Café Tacuba (Musical group) 12/12",
                  "Great Central Fair for the U.S. Sanitary Commission (1864 : Philadelphia, Pa.). "\
                  "Committee on Public Charities and Benevolent Institutions. Philadelphia [blank] 1864. "\
                  "619 Walnut Street. To [blank] ...",
                  "Deutsch Foundation Conference (1930 : University of Chicago). Care of the aged. 2000, 1972. Reprint.",
                  "Cahiers de civilisation médiévale. Bibliographie.",
                  "Jane Pickering's lute book. arr.",
                  "Magnificent Ambersons (Motion picture). Spanish.",
                  "Magnificent Ambersons (Motion picture). English.",
                  "Deutsche Geschichte. Band 6.",
                  "English pilot. The fourth book : describing the West India navigation, "\
                  "from Hudson's-Bay to the river Amazones ...",
                  "Industrial sales management game 5.",
                  "Masson, VeNeta. Rehab at the Florida Avenue Grill.",
                  "Masson, VeNeta. Rehab at the Florida Avenue Grill.",
                  "Sports illustrated.",
                  "Bulletin (North Carolina Agricultural Experiment Station)",
                  "Bellevue literary review :"]
    assert_equal rec['included_work'],
                 ["{\"author\":\"Saint-Saëns, Camille, 1835-1921.\","\
                  "\"title\":[\"Quartets,\",\"violins (2), viola, cello,\",\"no. 2, op. 153,\",\"G major\"]}",
                  "{\"author\":\"Schwenkel, Christina.\","\
                  "\"title\":[\"Architecture and dwelling in the 'war of destruction' in Vietnam.\"]}",
                  "{\"label\":\"Facsimile of\",\"author\":\"Ferrini, Vincent, 1913-2007.\","\
                  "\"title\":[\"Tidal wave : poems of the great strikes.\",\"1945\",\"(New York : Great-Concord Publishers)\"]}",
                  "{\"label\":\"Tome 1, volume 1: Contains\",\"author\":\"Plotinus.\","\
                  "\"title\":[\"Peri tou kalou.\",\"French\",\"(Achard and Narbonne)\"]}",
                  "{\"author\":\"Name, Author, (Test name), 1944-.\",\"title\":[\"Test title.\"]}",
                  "{\"author\":\"Kungliga Biblioteket (Sweden).\","\
                  "\"title\":[\"Manuscript.\",\"KB787a.\",\"Church Slavic.\",\"1966.\"]}",
                  "{\"author\":\"United States. Congress (94th, 2nd session : 1976).\","\
                  "\"title\":[\"Memorial services held in the House of Representatives and Senate of the United States, "\
                  "together with remarks presented in eulogy of Jerry L. Litton, late a Representative from Missouri.\",\"197.\"]}",
                  "{\"author\":\"North Carolina. Building Code Council.\","\
                  "\"title\":[\"North Carolina state building code.\",\"1,\",\"General construction.\",\"11X,\","\
                  "\"Making buildings and facilities accessible to and usable by the physically handicapped.\"]}",
                  "{\"author\":\"Germany (East).\",\"title\":[\"Treaties, etc.\",\"Germany (West),\",\"1990 May 18.\",\"1990.\"]}",
                  "{\"author\":\"Café Tacuba (Musical group)\",\"title\":[\"12/12\"]}",
                  "{\"author\":\"Great Central Fair for the U.S. Sanitary Commission (1864 : Philadelphia, Pa.). "\
                  "Committee on Public Charities and Benevolent Institutions.\","\
                  "\"title\":[\"Philadelphia [blank] 1864. 619 Walnut Street. To [blank] ...\"]}",
                  "{\"author\":\"Deutsch Foundation Conference (1930 : University of Chicago).\","\
                  "\"title\":[\"Care of the aged.\",\"2000,\",\"1972.\",\"Reprint.\"],\"issn\":\"1234-1234\"}",
                  "{\"title\":[\"Cahiers de civilisation médiévale.\",\"Bibliographie.\"],\"issn\":\"0240-8678\"}",
                  "{\"title\":[\"Jane Pickering's lute book.\",\"arr.\"],\"title_variation\":\"Drewries Accord's;\"}",
                  "{\"label\":\"Contains\",\"title\":[\"Magnificent Ambersons (Motion picture).\",\"Spanish.\"]}",
                  "{\"label\":\"Contains\",\"title\":[\"Magnificent Ambersons (Motion picture).\",\"English.\"]}",
                  "{\"label\":\"Guide: Based on\",\"title\":[\"Deutsche Geschichte.\",\"Band 6.\"]}",
                  "{\"title\":[\"English pilot.\",\"The fourth book : describing the West India navigation, "\
                  "from Hudson's-Bay to the river Amazones ...\"]}",
                  "{\"title\":[\"Industrial sales management game\",\"5.\"]}",
                  "{\"author\":\"Masson, VeNeta.\",\"title\":[\"Rehab at the Florida Avenue Grill.\"],"\
                  "\"isbn\":[\"0967368804\"]}",
                  "{\"label\":\"Contains\",\"title\":[\"Sports illustrated.\"]}",
                  "{\"title\":[\"Bulletin (North Carolina Agricultural Experiment Station)\"],"\
                  "\"title_variation\":\"1991 NC Agricultural Experiment Station Bulletin\"}"]
  end

  def test_misc_id_flattener
    config = {'misc_id' => {'flattener' => 'misc_id'}}
    rec = flatten_test_record('argot-misc-id-flattener.json', config).first
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
    config = {'note_performer_credits' => {'flattener' => 'note'}}
    rec = flatten_test_record('argot-note-flattener.json', config).first

    assert_equal rec['note_performer_credits'],
                 ["Cast: Ronald Colman, Elizabeth Allan, Edna May Oliver.",
                  "This should be displayed only",
                  "This should be displayed only, too"]
    assert_equal rec['note_performer_credits_indexed'],
                    ["Ronald Colman, Elizabeth Allan, Edna May Oliver.",
                    "This should be indexed instead"]
  end

  def test_title_variant_flattener
    config = {'title_variant' => {'flattener' => 'title_variant'}}
    rec = flatten_test_record('argot-title-variant-flattener.json', config).first

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

  def test_indexed_value_flattener
    config = {'physical_description' => {'flattener' => 'indexed_value'}}
    rec = flatten_test_record('argot-indexed-value-flattener.json', config).first

    assert_equal rec['physical_description'],
                 ["videodiscs: 1 videodisc (107 min.) : sound, color ; 4 3/4 in.", "volumes: 286 pages : illustrations ; 21 cm.",
                  "print: 1 reel of 1 (18 min., 30 sec.) (656 ft.) : opt sd., b&w ; 16 mm. with study guide."]
    assert_equal rec['physical_description_indexed'],
                    ["1 videodisc (107 min.) : sound, color ; 4 3/4 in.", "286 pages : illustrations ; 21 cm.",
                     "1 reel of 1 (18 min., 30 sec.) (656 ft.) : opt sd., b&w ; 16 mm. with study guide."]
  end
end
