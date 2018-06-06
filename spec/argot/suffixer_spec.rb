describe Argot::Suffixer do
  # rubocop:disable MethodLength
  let (:config) do 
    {
      id: 'id',
      trim: ['value'],
      vernacular: 'vernacular',
      lang: 'lang'
    }
  end

  let(:solr_fields) do
    {
      id: {
        type: 't',
        attr: %w[stored single]
      },
      title_sort: {
        type: 'str',
        attr: ['sort']
      },
      title_main: {
        type: 't',
        attr: %w[single]
      }
    }
  end

  context '#default_isntance' do
    it 'creates a working suffixer' do
      instance = Argot::Suffixer.new
      doc = get_json('argot-allgood.json')
      rec = Argot::Flattener.new.call(doc)
      result = instance.process(rec)
      expect(rec['title_main_value']).to be(result['title_main_t_stored_single'])
    end
  end

  context '#process' do 
    it 'succesfullly returns a record' do
      doc = get_json('argot-allgood.json')
      fdoc = Argot::Flattener.new.call(doc)
      rec = described_class.new(config: config, fields: solr_fields).call(fdoc)
      expect(rec).to have_key('title_main_t')
    end
  end
end
