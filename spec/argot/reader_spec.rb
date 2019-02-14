# frozen_string_literal: true

describe Argot::Reader do
  context '#each' do
    it 'returns an Enumerator' do
      open_file('argot-allgood.json') do |f|
        r = Argot::Reader.new(f)
        expect(r.each).to be_a(Enumerator)
      end
    end
  end

  context '#process' do
    it 'yields records to a block' do
      open_file('argot-allgood.json') do |f|
        count = 0
        described_class.new(f).process { |_x| count += 1 }
        expect(count).to (be > 0)
      end
    end
  end

  if RUBY_PLATFORM.match?(/java/)
    context 'when running under JRuby' do
      it 'successfully processes with a Java InputStream' do
        open_file('argot-allgood.json').to_inputstream do |f|
          recs = described_class.new(f).collect(&:itself)
          expect(recs.length).to be(1)
        end
      end
    end
  end
end
