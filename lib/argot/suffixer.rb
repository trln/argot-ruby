##
# Adds Solr Suffixes to Flattened Argot
class Argot::Suffixer

	def initialize(config, solr_fields)
    @solr_fields = solr_fields.inject({}){|ret,(k,v)| ret[k.to_sym] = v; ret}
    @config = config.inject({}){|ret,(k,v)| ret[k.to_sym] = v; ret}

    if !@config.key?(:id)
  		puts "config has no id attribute"
    end

    if @config.key?(:trim)
    	unless @config[:trim].is_a?(Array)
    		puts "Config's trim attribute is not an array"
  		end
		end
		if @config.key?(:ignore)
    	unless @config[:trim].is_a?(Array)
    		puts "Config's ignore attribute is not an array"
  		end
		end
  end

  def add_suffix(key,vernacular,lang)

		suffix = ""
		
		key = key.to_sym

		if @solr_fields.key?(key)

			type = @solr_fields[key]["type"]
			attributes = @solr_fields[key]["attr"].nil? ? [] : @solr_fields[key]["attr"]
			# add vernacular & language
			if vernacular
				suffix << "_#{lang}_v"
			end

			# add special sort value
			if attributes.include?("sort")
				intTypes = %w(i float long double)
				sort_suffix = intTypes.include?(type) ? "_isort" : "_ssort"
				suffix << sort_suffix
			else
				suffix << "_#{type}"
			end

			# add stored
			if attributes.include?("stored")
				suffix << "_stored"
			end

			# add single
			if attributes.include?("single")
				suffix << "_single"
			end

		else
			suffix = "_a"
		end

		"#{key}#{suffix}"
	end

	def normalize_key(key)
		if @config.has_key?(:trim)
			@config[:trim].each do |v|
				if key.end_with?("_#{v}")
					key = key.sub("_#{v}","")
				end
			end
		end
		key
	end

	def skip_key(key)
		skip = false
		if @config.has_key?(:ignore)
			@config[:ignore].each do |v|
				if key.end_with?("_#{v}")
					skip = true
				end
			end
		end
		skip
	end

	def process(input)
		suffixed = Hash.new

		unless @config[:lang].nil?
			lang = input["#{@config[:lang]}"].nil? ? "" : input["#{@config[:lang]}"]
		end
		
		input.each do |k,v|
			next if skip_key(k)

			nKey = normalize_key(k)
			vernacular = false
			# If @config has a vernacular value, trim and set vernacular to true
			unless @config[:vernacular].nil?
				if nKey.end_with?("_#{@config[:vernacular]}")

					unless !input.has_key?("#{nKey}_#{@config[:lang]}")
						lang = input["#{nKey}_#{@config[:lang]}"]
					end

					nKey = nKey.sub("_#{@config[:vernacular]}","")
					vernacular = true

				end
			end

			if k === "#{@config[:id]}"
				solrKey = 'id'
			else
				solrKey = add_suffix(nKey,vernacular,lang)
			end

			suffixed[solrKey] = v
		end

		suffixed
	end
	
end