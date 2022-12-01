begin
  require 'redis'
rescue LoadError
  warn("unable to load 'redis' gem which is required for authority database access")
end

module Argot
  # Argot::Transformer implementation that queries a Redis instance
  # for matching entries in an Argot record and adds the results 
  # to a 'variant_names' field.  This step should be run on 'raw'
  # Argot, before flattening and suffixing. 
  class AuthorityEnricher < Transformer
    attr_reader :redis

    # create a new instance
    # @param redis_url: the URL to a redis instance in the form `redis://[hostname]:[port]. If unspecified and the environment variable REDIS_URL is set, that is used, otherwise the default it used
    def initialize(redis_url: 'redis://localhost:6379/0', redis: nil)
      super
      url = ENV.fetch('REDIS_URL', redis_url)
      @redis = redis || Redis.new(url: url)
    end

    def process(rec)
      begin
        values = rec.fetch('names', []).select { |n| n['id'] }.map do |name|
          variant_names(name['id'])
        end.flatten.compact
        rec['variant_names'] = values unless values.empty?
      rescue StandardError => e
        warn("unable to enrich #{rec['id']}: #{e}")
      end
      rec
    end

    alias call process

    private

    def variant_names(name_uri)
      variant_names = variant_names_lookup(name_uri)
      variant_names_vern = (variant_names || []).map do |vn|
        next unless vn
        lang = ScriptClassifier.new(vn).classify
        r = { 'value' => vn }
        r['lang'] = lang if lang
        r
      end
      variant_names_vern unless variant_names_vern.empty?
    end

    def variant_names_lookup(uri)
      vn = redis.get(uri.sub('http://id.loc.gov/authorities/names/', 'lcnaf:'))
      JSON.parse(vn) if vn
    end
  end
end
