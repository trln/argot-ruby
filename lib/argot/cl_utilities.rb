# frozen_string_literal: true
require 'redis'

module Argot
  # helper methods for commandline operations
  module CommandLineUtilities


    # used to test whether we are running inside a container
    # some utilities may want to use different default URLs
    def in_container?
      File.exist?('/.dockerenv') || File.exist?('/run/.containerenv')
    end

    # connects to redis (if available) using standard fallbacks
    def redis_connect(options)
      backup_url = 'redis://host.containers.internal:6379/0'

      urls = [options[:redis_url]]
      if in_container? and options[:redis_url].include?('localhost')
          urls << backup_url
      end
      redis = urls.map { |u| Redis.new(url: u) }.find do |r|
        begin
          r.ping
          true
        rescue Redis::CannotConnectError
          warn "no redis available at #{r.id}" if options[:verbose]
          false
        end
      end
      if redis.nil?
        warn "Redis not available at #{urls}"
        exit(1)
      end
      warn "connected to redis at #{redis.id}" if options[:verbose]
      redis
    end

    # Ensures a #read able input 
    # @param [String, #read] input a filename or IO-style object.
    #   if nil, `$stdin` is used.
    # @return #read
    # @yieldparam [#read]
    def get_input(input = nil)
      input = $stdin if input.nil? || (input == '-')
      input = File.open(input, 'r') unless input.respond_to?(:read)
      if block_given?
        begin
          yield input
        ensure
          input.close if input.respond_to?(:close) && (input != $stdin)
        end
      end
      input
    end

    # Ensures a #read able output
    # @param [String, #write] output a filename or IO-style object
    #   if `nil`, `$stdout` is used
    #  @return #write
    #  @yieldparam [#write]
    def get_output(output = nil)
      output = $stdout if output.nil?
      output = File.open(output, 'w') unless output.respond_to?(:write)
      if block_given?
        begin
          yield output
        ensure
          output.close unless output == $stdout
        end
      else
        output
      end
    end

    # Gets a formatter for validation results
    # @param options [Thor::MethodOptiosn] method options from Thor
    # @return [#call(result)] a callable that returns a String.
    def formatter(options)
      case options.format
      when 'json'
        JSON.method(:generate)
      when 'pretty_json'
        JSON.method(:pretty_generate)
      else
        text_formatter(verbose: options.verbose)
      end
    end

    # Gets either a plain or 'pretty' JSON formatter
    def json_formatter(options = { pretty: false })
      options[:pretty] ? JSON.method(:pretty_generate) : JSON.method(:generate)
    end

    # Gets a reporter for validation results.
    # @return 
    def validation_reporter(options)
      formatter = formatter(options)
      lambda do |rec, results|
        if options.verbose
          errdoc = {
            id: rec.fetch('id', '<unknown id>'),
            msg: results.first_error,
            errors: []
          }
          results.errors.each_with_object(errdoc) do |err, ed|
            ed[:errors] << err
          end
          warn formatter.call(errdoc)
        else
          warn "Document #{rec.fetch('id', '<unknown id>')} skipped (#{results.first_error})"
        end
        false
      end
    end

    def text_formatter(options = { verbose: false })
      lambda do |errdoc|
        msgs = ["Document #{errdoc[:id]} skipped: #{errdoc[:msg]}"]
        if options[:verbose]
          errdoc[:errors].each do |err|
            msgs << "\t#{err[:rule]}"
            err[:errors].each do |em|
              msgs << "\t\t#{em}"
            end
          end
        end
        msgs.join("\n")
      end
    end
  end

  # Utility for creating pipelines to process records
  module Pipelines
    include CommandLineUtilities

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
      if options[:authorities]
        redis = redis_connect(options)
        Argot::AuthorityEnricher.new(redis: redis)
      end
    end


    def create_validator(options)
      validator = Argot::Validator.new
      reporter = validation_reporter(options)
      validate = lambda do |rec|
        validator.valid?(rec, &reporter)
      end
    end

    def validate_pipeline(options) 
      validate = create_validator(options)
      Argot::Pipeline.setup do
        filter(&validate)
      end
    end

    def flatten_pipeline(_options = {})
      flatten = Argot::Flattener.new.as_block
      authorities = load_authorities(options)
      Argot::Pipeline.setup do
        authorities unless authorities.nil?
        transform(&flatten)
      end
    end

    def suffix_pipeline(options = {})
      flatten = Argot::Flattener.new.as_block
      suffix = Argot::Suffixer.new.as_block

      authorities = load_authorities(options)
      Argot::Pipeline.setup do
        authorities unless authorities.nil?
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
        authorities if authorities
        transform(&flatten)
        transform(&suffix)
        filter(&solr_validate)
      end
    end
  end
end
