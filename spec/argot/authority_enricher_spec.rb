# frozen_string_literal: true

describe Argot::AuthorityEnricher do
  subject { described_class.new(redis: mock_redis) }

  let(:fake_name_db) { yaml_fixture('fake_name_database.yml')['names'] }

  let(:mock_redis) do
    Hash.alias_method(:get, :[])
    fake_name_db
  end

  let(:records_with_name_ids) do
    open_file('records-with-name-ids.json') do |f|
      JSON.load(f)
    end
  end

  let(:enriched_records) {
    records_with_name_ids.map { |x| subject.call(x) }
  }

  context 'spec setup' do
    it 'does not do the right thing' do
      expect(subject.redis).to be(mock_redis)
    end
  end

  context 'records with name.id' do
    it 'adds variant names for matching ids' do
      expect(enriched_records).to all(include('variant_names'))
    end

    it 'matches results to the expected keys' do
      # map of record IDs to shortened IDs found in 'names' on that record
      keys = enriched_records.each_with_object({}) do |rec, h|
        ids = rec['names'].select { |z| z['id'] }
                          .map { |y| y['id'] }.flatten
                          .map { |u| u.sub('http://id.loc.gov/authorities/names/', '') }
        h[rec['id']] = ids
      end
      # now do the same, but with the variant names (which all contain the id, see the fake name db)
      variants = enriched_records.each_with_object({}) do |rec, h|
        h[rec['id']] = rec['variant_names'].map { |vn| vn['value'] }.map { |v| v.sub(/.*-/, '') }.uniq
      end

      expect(keys).to eq(variants)
    end
  end
end
