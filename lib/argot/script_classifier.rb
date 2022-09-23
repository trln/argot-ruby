module Argot
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
