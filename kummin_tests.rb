$:.unshift File.dirname(__FILE__)
require 'kummin'
require 'test/unit'

class FolderMigrations < Kummin::StrictVersionMigrations
    # -> i yamlfilen står det Folder: version
    # versioned migration
    # version
    require 'fileutils'
    include FileUtils

    def up from, to
        $foldermigrations = to
        #mkdir('business_app')
    end
end

class InstallJavaMigrations < Kummin::JumpVersionMigrations
    # -> i yamlfilen står det InstallJava: version
    def up from, to

    end

end

class Config < Kummin::Configuration
    def initialize
        super(:version_file=> './test_version_file.yml')
    end
    
end

require 'fileutils'
class MigrationsTests < Test::Unit::TestCase

    def setup
        @c = Config.new()
    end

    def teardown
        @c.clear
    end

    def test_can_report_version_0
        assert_equal(0, @c.version())
    end

    def test_can_read_migrations
        m = @c.migrations()
        assert_equal(['FolderMigrations','InstallJavaMigrations'], m.map do |m| m.name end) 
    end

    def test_can_migrate_to_version_1
        @c.migrate()
        assert_equal(1, $foldermigrations) 
    end
end


