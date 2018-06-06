describe Argot::Pipeline do
  
  
  let(:words) { %w[one of these things first] }

  it 'transforms an array of words when manually configured' do
    t = Argot::Transformer.new(&:upcase)
    p = Argot::Pipeline.new | t
    results = []
    p.run(words) { |x| results << x }
    expect(results).to eq(%w[ONE OF THESE THINGS FIRST])
  end

  it 'filters an array of words when using the DSL' do
    words = %w[I've got a match]
    p = Argot::Pipeline.setup do
      filter { |x| !x.include?("'") }
    end
    results = []
    p.run(words) { |x| results << x }
    expect(results).to eq(%w[got a match])
  end

  it 'gathers results when asked to' do
    max_size = 3

    p = Argot::Pipeline.setup do
      gather(max_size)
      to_array
    end

    words = %w[bland names for bland results seven words]
    r = []
    p.run(words) { |x| r << x }
    r.collect(&:to_a)
    expect(r.length).to (be < words.length)
    expect(r).to all( satisfy("have fewer than #{max_size} sized chunks") { |x| x.length <= max_size }) 
    expect(r.flatten).to eq(words)
  end

  it 'scatters results when asked to' do 
    max_size = 3
    p = Argot::Pipeline.setup do
      gather max_size
    end | Argot::Scatterer.new
    words = %w[bland names for bland results seven words]
    r = []
    p.run(words) { |x| r << x }
    expect(r).to eq(words)
  end
end
