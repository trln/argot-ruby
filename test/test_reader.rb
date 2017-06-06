require_relative './util'
require 'minitest/autorun'
require 'argot'

class ArgotReaderTest < Minitest::Test
    def setup
        @instance = Argot::Reader.new
    end

    def test_instantiate
        refute_nil @instance
    end

    def test_process_file
        good = Util.get_file("argot-allgood.json")
        recs = []
        @instance.process(good) { |x| 
            recs << x
        }
        assert "'good' test file should have one record", recs.length == 1
        rec = recs[0]
        assert "'test record has proper 'publisher' imprint", rec['publisher'][0]['imprint'] == 'Moskva.'
    end

    if RUBY_PLATFORM =! 'java'

      def test_process_inputstream
        good = Util.get_file('argot-allgood.json').to_inputstream
        recs = []
        @instance.process(good) { |x| recs << x }
        assert recs.length == 1
      end
    end


end
            

