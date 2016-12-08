require_relative './util'
require 'minitest/autorun'
require 'json'
require 'argot'

class ArgotFlattenerTest < Minitest::Test
    
    def test_process_file
        good = Util.get_file("argot-allgood.json");
        doc = JSON.parse(good.read);
        recs = []
        recs << Argot::Flattener.process(doc)

        assert "'good' test file should have one record", recs.length == 1
        rec = recs[0]
        assert "'test record's first 'authors_other_vernacular_lang' is correct", rec['authors_other_vernacular_lang'][0] == "/(N"
    end

end
            

