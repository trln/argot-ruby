describe Argot::Suffixer do
  # rubocop:disable MethodLength
  let (:config) do 
    {
      id: 'id',
      trim: ['value'],
      vernacular: 'vernacular',
      lang: 'lang',
      rollup_id: 'rollup_id'
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

  context '#call' do 
    it 'transforms a record using a simple configuration' do
      doc = get_json('argot-allgood.json')
      fdoc = Argot::Flattener.new.call(doc)
      rec = described_class.new(config:config, fields: solr_fields).call(fdoc)
      expect(rec).to have_key('title_main_t')
    end

    it 'does not suffix the rollup_id field' do
      doc = get_json('argot-allgood.json')
      fdoc = Argot::Flattener.new.call(doc)
      rec = described_class.new(config:config, fields: solr_fields).call(fdoc)
      expect(rec).to have_key('rollup_id')
    end

    it 'suffixes subject_headings_* correctly' do
      doc = get_json('argot-problem-subjects.json')
      fdoc = Argot::Flattener.new.call(doc)
      rec = described_class.new.call(fdoc)
      expect(rec).to have_key('subject_headings_remapped_t')
      expect(rec).to have_key('subject_headings_t_stored')
    end
  end
end
