lib = File.expand_path('../lib/', __FILE__)

$:.unshift(lib) unless $:.include?(lib)

require 'argot'

is_java = RUBY_PLATFORM =~ /java/

Gem::Specification.new do |s|
    s.name          = 'argot'
    s.version       = Argot::VERSION
    s.date          = '2016-10-10'
    s.summary       = 'Tools for shared ingest infrastructure'
    s.description   = 'see summary?'
    s.authors       = ['Adam Constabaris','Luke Aeschleman']
    s.files         = Dir.glob("{bin,lib}/**/*.rb") + %w(LICENSE README.md ROADMAP.md CHANGELOG.md)
    #if is_java 
    #    s.files += [ 'lib/*.jar' ]
    #end

    s.require_path  = 'lib'
    s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

    s.add_runtime_dependency 'rubyzip', [ '~> 1.2' ]
    if is_java 
        s.add_runtime_dependency 'jbundler', ['~> 0.9', '>=0.9.3']
        s.requirements << "jar org.noggit:noggit, 0.7"
    end
    s.add_runtime_dependency 'yajl-ruby', ['~> 1.2', ">=1.2.1"]
    s.add_runtime_dependency 'nokogiri', [ '~> 1.6', '>= 1.6.8']
    s.add_runtime_dependency 'traject', [ '~> 2.0' ]
    s.add_runtime_dependency 'lisbn', ['~> 0.2' ]
    spec.add_runtime_dependency 'thor'

end
