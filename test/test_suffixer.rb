require_relative './util'
require 'minitest/autorun'
require 'json'
require 'argot'

class ArgotSuffixerTest < Minitest::Test

		def setup
			config = {
        	:id => 'id',
        	:trim => ['value'],
        	:vernacular => 'vernacular',
        	:lang => 'lang'
        }

        solr_fields = {
        	:id => {
        		:type => 't',
        		:attr => ['stored','single']
        	},
        	:title_sort => {
        		:type => 'str',
        		:attr => ['sort']
        	},
        	:title_main => {
        		:type => 't',
        		:attr => ['single']
        	}
        }
        @instance = Argot::Suffixer.new(config, solr_fields)
    end

    def test_instantiate
        refute_nil @instance
    end
    
    def test_process_file
        good = Util.get_file("argot-allgood.json");
        doc = JSON.parse(good.read);
        recs = []
        recs << Argot::Flattener.process(doc)
        rec = recs[0]
      	rec = @instance.process(rec)
        
        assert "title_main became title_main_t_single is correct", rec.key?('title_main_t_single')
    end

end
            

