require 'minitest/autorun'
require 'argot/reader'


module Util
    TEST_FILES = File.expand_path("../data", __FILE__)

    def self.get_file(name) 
        f = File.new(File.join(Util::TEST_FILES, name))
        if not File.exist?(f)
            raise "Unable to find required test file #{name}"
        end
        f
    end
end

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
        assert "'good' test file should have no errors", @instance.errors.empty?
    end

end
            

