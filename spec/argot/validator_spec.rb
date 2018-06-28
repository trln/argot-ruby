describe Argot::Validator do

  let(:invalid_rec) { { 'id' => '12345' } }

  let(:minimal_valid_rec) do
      { 'id' => '12345', 'title_main' => 'gooby', 'local_id' => {'value' => 'empty'}, 'institution' => [ 'trln']  }
  end

  context '#from_files' do
    it 'sucessfully instantiates' do
		  expect(described_class.from_files).not_to be_nil
	   end
  end

  context '#valid?' do
    it 'rejects an invalid document' do
      expect(described_class.new.valid?(invalid_rec)).to be(false)
    end

    it 'passes a valid document' do
      expect(described_class.new.valid?(minimal_valid_rec)).to be(true)
    end

    it 'passes results for invalid record to a handler block' do
      stuff = []
      vr = described_class.new.valid?(invalid_rec) do |r2, results|
        stuff << [ r2, results ]
        expect(r2).to eq(invalid_rec)
        expect(results.errors).not_to be_empty
      end
      expect(vr).to be(false)
      expect(stuff).not_to be_empty
    end

    it 'does not pass results for valid record to a handler block' do
      stuff = []
      vr = described_class.new.valid?(minimal_valid_rec) do |r2, results|
        stuff << [r2, results]
        fail "handler was called on valid record (#{results.errors.first})"
      end
      expect(vr).to be(true)
      expect(stuff).to be_empty
    end
  end
end
