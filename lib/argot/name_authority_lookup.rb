require 'yaml'
require 'open-uri'
require 'redis'
require 'mock_redis'
require 'logger'

module Argot
  module NameAuthorityLookup

    # Note: If there's no ENV var containing a REDIS_URL
    #       then use a mock Redis object. Useful for testing.
    #       Potentially useful in local command line situations
    #       where Redis is not available.
    REDIS = if ENV.fetch('REDIS_URL', nil)
              Redis.new(host: ENV.fetch('REDIS_URL', nil))
            else
              MockRedis.new
            end

    def self.variant_names_redis_lookup(name_uri)
      variant_name = REDIS.get(name_uri.sub('http://id.loc.gov/authorities/names/', 'lcnaf:'))

      return JSON.parse(variant_name) if variant_name
    end

    def self.variant_names(name_uri)
      variant_names = variant_names_redis_lookup(name_uri)

      variant_names_vern = (variant_names || []).map do |variant_name|
        next unless variant_name
        lang = ScriptClassifier.new(variant_name).classify
        if lang
          { 'value' => variant_name, 'lang' => lang }
        else
          { 'value' => variant_name }
        end
      end

      variant_names_vern unless variant_names_vern.empty?
    end

    class ScriptClassifier
      attr_reader :value

      def initialize(value)
        @value = value.to_s
      end

      def classify
        case
        when is_cjk?
          'cjk'
        when is_cyrillic?
          'rus'
        when is_arabic?
          'ara'
        end
      end

      def is_cjk?
        classifier(cjk_matcher)
      end

      def is_cyrillic?
        classifier(cyrillic_matcher)
      end

      def is_arabic?
        classifier(arabic_matcher)
      end

      private

      def classifier(pattern)
        char_pattern_match_count = value.scan(pattern).length
        return true if (char_pattern_match_count.to_f / value.length) > 0.1
      end

      def cjk_matcher
        /\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/
      end

      def cyrillic_matcher
        /\p{Cyrillic}/
      end

      def arabic_matcher
        /\p{Arabic}/
      end
    end
  end
end
