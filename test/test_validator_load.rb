require 'minitest/autorun'
require 'argot/validator'

class ValidatorTest < Minitest::Test

        def setup
            @instance = Argot::Validator.from_files
        end

        def test_instantiate
            refute_nil @instance
        end

        def test_default_procesor 
            flunk "Not written yet"
        end

end
            

