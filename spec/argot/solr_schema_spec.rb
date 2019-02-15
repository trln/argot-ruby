# frozen_string_literal: true

describe Argot::SolrSchema do
  let(:bad_date) { 'bad-date-value.json' }

  it 'it compiles a schema' do
    instance = described_class.new
    expect(instance.fielddefs).not_to be_empty
  end

  it 'identifies a flattened date field as a date field' do
    instance = described_class.new
    # this field is copied to `*_dt` and the date type
    # is only specified on the latter
    field = 'date_cataloged_dt_stored_single'
    m = instance.send :find_matcher, field
    expect(m).not_to be_nil
    expect(m[:field_type]).to eq('date')
  end

  it 'identifies a record with a bad date field as invalid' do
    rec = argot_reader(bad_date).first
    result = described_class.new.analyze(rec)
    expect(result).not_to be_empty
    expect(result).to have_key('date_cataloged_dt_stored_single')
    expect(result['date_cataloged_dt_stored_single'].first).to match(/does not match pattern/)
  end
end
