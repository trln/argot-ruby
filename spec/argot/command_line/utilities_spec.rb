require 'argot/command_line'

describe Argot::CommandLine::Utilities do
  let(:instance) { Class.new { extend described_class } }

  let(:pipelines) { Class.new { extend Argot::CommandLine::Pipelines } }

  let(:mock_redis) { create_mock_redis }

  let(:options) { { authorities: true, redis: mock_redis } }

  let(:noauth_options) { { authorities: false, redis: mock_redis } }

  context 'pipeline setup' do 
    it '[flatten] adds authority processing' do
      fp = pipelines.flatten_pipeline(options)
      expect(fp.stages).to include(satisfy { |t| t.name == 'authorities' })
    end

    it '[flatten] does not add authorities when :authorities is false' do
      fp = pipelines.flatten_pipeline(noauth_options)
      expect(fp.stages).not_to include(satisfy { |t| t.name == 'authorities' })
    end

    it '[suffix] adds authority processing' do
      fp = pipelines.suffix_pipeline(options)
      expect(fp.stages).to include(satisfy { |t| t.name == 'authorities' })
    end

    it '[suffix] does not add authorities when :authorities is false' do
      fp = pipelines.suffix_pipeline(noauth_options)
      expect(fp.stages).not_to include(satisfy { |t| t.name == 'authorities' })
    end


    it '[everything] adds authority processing' do
      fp = pipelines.everything_pipeline(options)
      expect(fp.stages).to include(satisfy { |t| t.name == 'authorities' })
    end

    it '[everything] does not add authorities when :authorities is false' do
      fp = pipelines.everything_pipeline(noauth_options)
      expect(fp.stages).not_to include(satisfy { |t| t.name == 'authorities' })
    end
  end

  context 'does authority processing on default pipelines' do
    let(:records_with_name_ids) do
      open_file('records-with-name-ids.json') do |f|
        JSON.load(f)
      end
    end

    it '[flatten] does authority processing' do
      fp = pipelines.flatten_pipeline(options)
      result = collect_pipeline_results(fp, records_with_name_ids)
      expect(result).to all(include('variant_names_value'))
    end

    it '[suffix] does authority processing' do
      fp = pipelines.suffix_pipeline(options)
      result = collect_pipeline_results(fp, records_with_name_ids)
      expect(result).to all(include('variant_names_tp'))
    end

    it '[everything] does authority processing' do
      fp = pipelines.everything_pipeline(options)
      result = collect_pipeline_results(fp, records_with_name_ids)
      expect(result).to all(include('variant_names_tp'))
    end
  end
end 
