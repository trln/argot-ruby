require_relative './util'
require 'minitest/autorun'
require 'argot/xml'

class EventParserTest < Minitest::Test

        def setup
            @instance = Argot::XML::ICEExtractor.new(Util.get_file("ice-data.xml"))
        end


        def test_default_procesor 
          recs = []
          @instance.each { |x| recs << x }

          assert_equal 1, recs.length, "Should have one record in the test file"
          assert(recs[0].has_key?(:chapters), "Should be a :chapters key in result")
          assert_equal(3, recs[0][:chapters].length, "Should be three chapters")
          assert_equal("Chapter One", recs[0][:chapters][0][:title], "Unexpected chapter title in first position")


        end

end
            

