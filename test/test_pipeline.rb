require 'minitest/autorun'
require 'argot/pipeline'

class PipelineTest < Minitest::Test

        def setup
            @results = []
            @collector = lambda { |x| @results << x }
            @words = %w[one of these things first]
        end

        def test_transform_array_pipe
            t = Argot::Transformer.new { |x| x.upcase }
            p = Argot::Pipeline.new | t
            p.run(@words)  { |x| @results << x }
            assert %w[ONE OF THESE THINGS FIRST] == @results
        end
end
            

