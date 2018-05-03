require 'pp'

module Argot
  # utility method to convert string keys of a hash to symbolx
  def self.symbolize_hash(h)
    h.each_with_object({}) { |(k, v), m| m[k.to_sym] = v }
  end
  #Converts flattened Arrgot to Solr document
  class Suffixer
    INT_TYPES = %w[i float long double].freeze
    LANG_CODE = 'lang_code'.freeze
    VERNACULAR = 'vernacular'.freeze

    attr_reader :config, :lang_code, :vernacular

    # Gets an instance using the default configuration
    def self.default_instance
      path = File.expand_path('../../data/', __FILE__)
      config = YAML.parse_file(File.join(path, 'solr_suffixer_config.yml')).transform
      fields = YAML.parse_file(File.join(path, 'solr_fields_config.yml')).transform
      Suffixer.new(config, fields)
    end

    def initialize(config, solr_fields)
      @solr_fields = Argot.symbolize_hash(solr_fields)
      @config = Argot.symbolize_hash(config)
      warn("config has no id atttribute: #{@config}") unless @config.key?(:id)
      read_config
    end

    def read_config
      @vernacular = @config.fetch(:vernacular, VERNACULAR)
      @lang_code = @config.fetch(:lang_code, LANG_CODE)
      warn("Config's trim attribute is not an array") unless @config.fetch(:trim, []).is_a?(Array)
      warn("Config's :ignore is not an array") unless @config.fetch(:trim, []).is_a?(Array)
      # @solr_fields.each do |k, v|
      # @solr_fields[k] = Argot.symbolize_hash(v) if v.is_a?(Hash)
      # end
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
  end
end
