require 'yaml'

##
# Flattens nested Argot JSON
module Argot

  # Flattens an argot hash
  class Flattener

  	include Methods

  	attr_accessor :config

  	attr_reader :flatteners

  	DATA_LOAD_PATH = File.expand_path('../data', __dir__)

  	DEFAULT_FILE = 'flattener_config.yml'

    def initialize(options = {})
    	@config = options.fetch(:config, load_config(options))
    	# cache flattener instances by name
    	@flatteners = Hash.new { |h, name|
    		h[name] = flatten_klass(name).new(@config)
    	}
    end


    # def combine(hash1, hash2)
    #   hash2.each do |k, v|
    #     if hash1.key?(k)
    #       hash1[k] = Array(hash1[k])
    #       hash1[k] = hash1[k] + v
    #     else
    #       hash1[k] = v
    #     end
    #   end
    #   hash1
    # end

    def process(input)
      flattened = {}
      input.each do |k, v|
        flattened = combine(flattened, flatteners[k].flatten(v, k)) unless v.nil?
      end

      flattened.each do |k, v|
        flattened[k] = v[0] if v.length == 1
      end
    end

    def flatten_klass(key)

      case config.fetch(key, {}).fetch('flattener', '')
      when 'indexed_value'
        Argot::FlattenIndexedValue
      when 'misc_id'
        Argot::FlattenMiscId
      when 'note'
        Argot::FlattenNote
      when 'title_variant'
        Argot::FlattenTitleVariant
      when 'work_entry'
        Argot::FlattenWorkEntry
      else
        Argot::FlattenDefault
      end
    end

    alias call process

    private 

    def load_config(options = {})
    	location = options.fetch(:config_file, File.join(DATA_LOAD_PATH, DEFAULT_FILE))
    	YAML.load_file(location)
    end
  end

  # superclass for special case per-field flatteners
  class TypeFlattener
  	include Methods

  	attr_accessor :config

  	def initialize(config = {})
  		@config = config
  	end
  end
end