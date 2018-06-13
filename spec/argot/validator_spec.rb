describe Argot::Validator do

  context '#from_files' do
    it 'sucessfully instantiates' do
		  expect(described_class.from_files).not_to be_nil
	   end
  end
end
