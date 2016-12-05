require 'rake/testtask'
begin
    if RUBY_PLATFORM =~ /java/
        require 'jars/installer'
    end
rescue LoadError
   puts "Hmm, not running on JRuby" 
end

Rake::TestTask.new do |t|
        t.libs << 'test'
end

desc "Run tests"
task :default => :test
