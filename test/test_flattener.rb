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
end
