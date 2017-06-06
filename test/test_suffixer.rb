require_relative './util'
require 'minitest/autorun'
require 'json'
require 'argot'

require 'pp'
# tests for suffixing (conversion to solr fields)
class ArgotSuffixerTest < Minitest::Test
  # rubocop:disable MethodLength
  def setup
    config = {
      id: 'id',
      trim: ['value'],
      vernacular: 'vernacular',
      lang: 'lang'
    }

    solr_fields = {
      id: {
        type: 't',
        attr: %w[stored single]
      },
      title_sort: {
        type: 'str',
        attr: ['sort']
      },
      title_main: {
        type: 't',
        attr: %w[single]
      }
    }
    @instance = Argot::Suffixer.new(config, solr_fields)
  end

  def test_instantiate
    refute_nil @instance
  end

  def test_default_instance
    puts "\n\n -- default_instance ---\n\n"
    instance = Argot::Suffixer.default_instance
    doc = Util.get_json('argot-allgood.json')
    rec = Argot::Flattener.process(doc)
    result = instance.process(rec)
    assert_equal rec['title_main_value'], result['title_main_t_stored_single']
  end

  def test_process_file
    doc = Util.get_json('argot-allgood.json')
    recs = []
    recs << Argot::Flattener.process(doc)
    rec = recs[0]
    rec = @instance.process(rec)
    assert 'title_main became title_main_t_single is correct', rec.key?('title_main_t_single')
  end
end
