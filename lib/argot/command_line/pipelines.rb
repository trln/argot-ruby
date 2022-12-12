module Argot
  class CommandLine
    # Utility for creating pipelines to process records
    module Pipelines
      include CommandLine::Utilities

      DATA_LOAD_PATH = File.expand_path('../data', __dir__)

      def configuration_paths(options)
        {
          flattener_config_path: YAML.load_file(File.join(DATA_LOAD_PATH, options.flattener_config)),
          fields_path: File.join(DATA_LOAD_PATH, options.fields)
        }
      end

      # gets an AuthorityEnricher as a block if the `authorities`
      # option is present, `nil` otherwise.
      def load_authorities(options)
        return unless options[:authorities]

        redis = options.fetch(:redis, redis_connect(options))
        Argot::AuthorityEnricher.new(redis: redis).as_block
      end

      def create_validator(options)
        validator = Argot::Validator.new
        reporter = validation_reporter(options)
        lambda do |rec|
          validator.valid?(rec, &reporter)
        end
      end

      def validate_pipeline(options)
        validate = create_validator(options)
        Argot::Pipeline.setup do
          filter(&validate)
        end
      end

      def flatten_pipeline(options = {})
        flatten = Argot::Flattener.new.as_block
        authorities = load_authorities(options)
        Argot::Pipeline.setup do
          transform({ name: 'authorities' }, &authorities) unless authorities.nil?
          transform(&flatten)
        end
      end

      def suffix_pipeline(options = {})
        flatten = Argot::Flattener.new.as_block
        suffix = Argot::Suffixer.new.as_block

        authorities = load_authorities(options)
        Argot::Pipeline.setup do
          transform({ name: 'authorities' }, &authorities) unless authorities.nil?
          transform(&flatten)
          transform(&suffix)
        end
      end

      def everything_pipeline(options)
        validate = create_validator(options)
        flatten = Argot::Flattener.new.as_block
        suffix = Argot::Suffixer.new.as_block
        schema = Argot::SolrSchema.new
        authorities = load_authorities(options)
        solr_validate = lambda do |rec|
          res = schema.analyze(rec)
          unless res.empty?
            rep = { 'id' => rec['id'],
            'validator' => 'solr' }
            rep.update(res)
            warn rep.to_json
          end
          res.empty?
        end

        Argot::Pipeline.setup do
          filter(&validate)
          transform({ name: 'authorities' }, &authorities) unless authorities.nil?
          transform(&flatten)
          transform(&suffix)
          filter(&solr_validate)
        end
      end
    end
  end
end
