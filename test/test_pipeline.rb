require 'minitest/autorun'
require 'argot/pipeline'

class PipelineTest < Minitest::Test
  def setup
    @results = []
    @words = %w[one of these things first]
  end

  def test_transform_array_pipe
    t = Argot::Transformer.new(&:upcase)
    p = Argot::Pipeline.new | t
    p.run(@words) { |x| @results << x }
    assert %w[ONE OF THESE THINGS FIRST] == @results
  end

  def test_transform_array_dsl
    p = Argot::Pipeline.setup do
      filter { |x| !x.include?("'") }
    end
    words = %w[I've got a match]
    p.run(words) { |x| @results << x }
    assert %w[got a match] == @results
  end

  def test_gather_dsl
    max_size = 3
    p = _gather_array_pipeline(max_size)
    words = %w[bland names for bland results seven words]
    @r = []
    p.run(words) { |x| @r << x }
    @r.collect(&:to_a)
    assert @r.all? { |x| x.length <= max_size }
    assert_equal words, @r.flatten!
  end

  def test_scatter_dsl
    p = _gather_pipeline(3) | Argot::Scatterer.new
    words = %w[bland names for bland results seven words]
    @r = []
    p.run(words) { |x| @r << x }
    assert_equal words, @r
  end

  private

  def _gather_array_pipeline(max_size)
    Argot::Pipeline.setup do
      gather(max_size)
      to_array
    end
  end

  def _gather_pipeline(max_size)
    Argot::Pipeline.setup do
      gather max_size
    end
  end
end
