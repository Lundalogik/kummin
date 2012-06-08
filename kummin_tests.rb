$:.unshift File.dirname(__FILE__)
require 'kummin'
require 'test/unit'

class FolderMigrations < Kummin::StrictVersionMigrations
    attr_reader :executed_steps
    # -> i yamlfilen står det Folder: version
    # versioned migration
    # version
    require 'fileutils'
    include FileUtils
    def initialize()
        @executed_steps = []
    end

    def up from, to
        $foldermigrations = to
        super from, to
    end

    def step_1
        @executed_steps.push(1)
    end

    def step_2
        @executed_steps.push(2)
    end
end

class InstallJavaMigrations < Kummin::JumpVersionMigrations
    # -> i yamlfilen står det InstallJava: version
    def up from, to
    end

end

class With3StepsMigrations < Kummin::StrictVersionMigrations
    attr_reader :executed_steps
    def initialize()
        @executed_steps = []
    end
    
    def step_2
        @executed_steps.push(2)
    end

    def step_1
        @executed_steps.push(1)
    end

    def step_3
        @executed_steps.push(3)
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
        $foldermigrations = nil 
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
        assert_equal(['FolderMigrations','InstallJavaMigrations', 'With3StepsMigrations'], 
                     m.map do |m| m.name end) 
    end

    def test_can_migrate_to_version_1
        @c.migrate()
        assert_equal(1, $foldermigrations) 
    end

    def test_can_report_all_migrate_steps_in_migrations
        steps = FolderMigrations.new.all_steps
        assert_equal([1,2], steps)
    end

    def test_will_run_steps_on_up
        f = FolderMigrations.new
        f.up(0,2)
        assert_equal([1,2], f.executed_steps)
    end
    def test_will_run_only_trailing_steps_on_up
        f = FolderMigrations.new
        f.up(1,2)
        assert_equal([2], f.executed_steps)
    end

    def test_will_run_steps_in_correct_order
        w = With3StepsMigrations.new
        w.up(0,3)
        assert_equal([1,2,3], w.executed_steps)
    end

end


