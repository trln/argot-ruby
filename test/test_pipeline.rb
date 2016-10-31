require 'minitest/autorun'
require 'argot/pipeline'

class PipelineTest < Minitest::Test

        def setup
            @results = []
            @words = %w[one of these things first]
        end

        def test_transform_array_pipe
            t = Argot::Transformer.new { |x| x.upcase }
            p = Argot::Pipeline.new | t
            p.run(@words)  { |x| @results << x }
            assert %w[ONE OF THESE THINGS FIRST] == @results
        end

        def test_transform_array_dsl 
            p = Argot::Pipeline.setup {
                filter { |x| not x.include?("'") }
            }
            words = %w[I've got a match]
            p.run(words) { |x| @results << x }
            assert %w[got a match] == @results
        end
end