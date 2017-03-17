require_relative './util'
require 'minitest/autorun'
require 'json'
require 'argot'
require 'argot/command_line'
require 'thor'

class ArgotCommandLineTest < MiniTest::Test
    
    def get_input_with_nil_yields_stdin
        assert $stdin == Argot::CommandLine.get_input
    end

    def get_input_with_dash_yields_stdin
        assert $stdin == Argot::CommandLine.get_input('-')
    end

    def get_input_with_io_yields_original
        good = Util.get_file("argot-allgood.json")
        assert good == Argot::CommandLine.get_input(good)
    end

    def test_flatten
        input = Util.find_file("argot-oneline.json")
        orig = $stdout
        output = StringIO.new
        $stdout = output
        cl = Argot::CommandLine.new
        cl.flatten(input)
        $stdout = orig
        assert output.string.length > 0 
    end
end
            

