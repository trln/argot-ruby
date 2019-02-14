# frozen_string_literal: true

require 'tempfile'

describe Argot::Splitter do
  def instance_with_tmpdir(chunk_size: 2, pattern: described_class::DEFAULT_PATTERN)
    Dir.mktmpdir do |dir|
      described_class.new(dir, chunk_size: chunk_size, pattern: pattern) do |i|
        yield i, dir
      end
    end
  end

  it 'does not open a file until at least one record has been written' do
    instance_with_tmpdir do |i, _|
      aggregate_failures do
        expect(i.current_file).to be_nil
        i.write('hello')
        expect(i.current_file).not_to be_nil
      end
    end
  end

  it 'splits records into the exepected number of files' do
    instance_with_tmpdir(chunk_size: 2, pattern: '%d.txt') do |i, dir|
      %w[one two three four five six seven].each do |n|
        i.write("#{n}\n")
      end
      # note you can't expect the final file to be flushed unless you call close
      i.close

      files = Dir.glob("#{dir}/*.txt")
      aggregate_failures do
        expect(files.length).to eq(4)
        files.each do |f|
          expect(`wc -l #{f}`.to_i).to be_between(1, 2).inclusive
        end
      end
    end
  end
end
