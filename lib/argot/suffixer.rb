require 'pp'

module Argot
  # Converts flattened Arrgot to Solr document
  class Suffixer
    include Methods


    DEFAULT_PATH = File.expand_path('../data', __dir__)

    DEFAULT_CONFIG = 'solr_suffixer_config.yml'

    DEFAULT_FIELDS = 'solr_fields_config.yml'

    INT_TYPES = %w[i float long double].freeze

    LANG_CODE = 'lang_code'.freeze

    VERNACULAR = 'vernacular'.freeze

    attr_reader :config, :lang_code, :vernacular

    def initialize(options = {})
      config = options.fetch(:config, DEFAULT_CONFIG)
      fields = options.fetch(:fields, DEFAULT_FIELDS)
      @config = config.is_a?(Hash) ? config : load_yaml(config)
      @solr_fields = fields.is_a?(Hash) ? fields : load_yaml(fields)
    end
    
    # Creates a new suffixer
    # @param [Hash] options for loading configuration
    # @opt options [String, Hash] :config if a string, a YAML filename from which
    #   to load the basic suffixer configuration.  If a Hash, contains the 
    #   configuration itself.
    # @opt options [String, Hash] :fields if a string, a YAML filename from which
    #   to load the Solr field configuration.  If a hash, contains the solr
    #   field configuration itself.
    # Default configuration will be loaded from `File.join(DEFAULT_PATH, DEFAULT_CONFIG)`
    # and default Solr fields are loaded from `File.join(DEFAULT_PATH, DEFAULT_FIELDS)
    def initialize(options = {})
      config = options.fetch(:config, File.join(DEFAULT_PATH, DEFAULT_CONFIG))
      fields = options.fetch(:fields, File.join(DEFAULT_PATH, DEFAULT_FIELDS))
      @config = config.is_a?(String) ? load_yaml(config) : config
      @solr_fields = fields.is_a?(String) ? load_yaml(fields) : fields
      read_config
    end

    def read_config
      @vernacular = @config.fetch(:vernacular, VERNACULAR)
      @lang_code = @config.fetch(:lang_code, LANG_CODE)
      warn("config has no id atttribute: #{@config}") unless @config.key?(:id)
      warn("Config's trim attribute is not an array") unless @config.fetch(:trim, []).is_a?(Array)
      warn("Config's :ignore is not an array") unless @config.fetch(:ignore, []).is_a?(Array)
    end

    def add_suffix(key, vernacular, lang)
      suffix = ''
      key = key.to_sym
      field_conf = @solr_fields[key]
      if !field_conf.nil?
        type = field_conf[:type] || field_conf['type'] || 't'
        attributes = field_conf.fetch('attr', [])
        # add vernacular & language
        if vernacular
          #warn("lang is empty for #{key}") if lang.nil? || lang.empty?
          suffix << "_#{lang.is_a?(Array) ? lang[0] : lang}_v"
        else
          # add special sort value
          if attributes.include?('sort')
            sort_suffix = INT_TYPES.include?(type) ? '_isort' : '_ssort'
            suffix << sort_suffix
          else
            suffix << "_#{type}"
          end
          suffix << '_stored' if attributes.include?('stored')
          suffix << '_single' if attributes.include?('single')
        end
      else
        suffix = '_a'
      end
      "#{key}#{suffix}"
    end

    def normalize_key(key)
      @config.fetch(:trim, []).each do |v|
        key = key.sub("_#{v}", '') if  key.end_with?("_#{v}")
      end
      key
    end

    def skip_key(key)
      # todo check this logic
      key = key.first if key.is_a?(Array)
      @config.fetch(:ignore, []).any? { |v| key.end_with?("_#{v}") }
    end

    def process(input)
      suffixed = {}
      input.reject { |k, _| skip_key(k) }
        .map { |k, v| [k, normalize_key(k), v] }
        .each do |orig_key, k, v|
          vern = false       
          if k.end_with?("_#{@vernacular}")
            lang = input.fetch("#{k}_#{lang_code}", '')
            k = k.sub("_#{@vernacular}", '')
            vern = true
          end

          solr_key =
            case orig_key
            when @config.fetch(:id, 'id')
              'id'
            else
              add_suffix(k, vern, lang)
            end
          if solr_key.index('single') && v.is_a?(Array) && v.size > 1
            warn("Found #{v.size} values for #{input[@config[:id]]}: #{solr_key}")
            suffixed[solr_key] = v[0]
          else
            suffixed[solr_key] = v
          end
        end
      suffixed
    end

    alias call process

    private

    def load_yaml(name)
      name = File.exist?(name) ? name : File.join(DEFAULT_PATH, name)
      File.open(name) do |f|
        symbolize_hash(YAML.safe_load(f))
      end
    end
  end
end
