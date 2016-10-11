require 'minitest/autorun'
require 'argot/xml'

class EventParserTest < Minitest::Test

        def setup
            @instance = Argot::XML::EventParser.new("USMARC")
        end

        def test_instantiate
            refute_nil @instance
        end

        def test_default_procesor 
            flunk "Not written yet"
        end

end
            

