require 'rake/testtask'

namespace :kummin do
    dir = File.dirname(__FILE__)
    desc "run the tests"
    Rake::TestTask.new do |t|
        t.libs << "test"
        t.test_files = FileList[File.join(dir,'*_tests.rb')]
        t.verbose = true
    end
end
