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
        @count_commits = 0
    end

    def step_1
        @executed_steps.push('1')
    end

    def step_2
        @executed_steps.push('2')
    end

end
class InstallJavaMigrations < Kummin::Migrations
    attr_reader :executed_steps
    def initialize()
        @executed_steps = []
    end
    def all_steps()
        return ['1.5.1','1.6.1', '1.8']
    end
    def first_version
        return '1.5.1'
    end
    def commit
    end
    def up from, to
        @executed_steps.push(to)
    end
end
class SeveralMigrations < Kummin::StrictVersionMigrations
    attr_reader :executed_steps
    def initialize()
        @executed_steps = []
    end
    def step_10
    end
    def step_12
    end
    def step_12_1
    end
    def step_12_2
    end
    def step_1
    end
    def step_2
    end
    def step_9
    end
    def up from, to
        @executed_steps.push({:from=>from,:to=>to})
    end
end

class With3StepsMigrations < Kummin::StrictVersionMigrations
    attr_reader :executed_steps
    def initialize()
        @executed_steps = []
    end
    
    def step_2
        @executed_steps.push('2')
    end

    def step_1
        @executed_steps.push('1')
    end

    def step_3
        @executed_steps.push('3')
    end
end

class NoStepsMigrations < Kummin::StrictVersionMigrations

end

class KumminConfig < Kummin::Migrator
    def initialize
        super(:version_file=> './test_version_file.yml')
    end
end

class FakeVersions
    attr_reader :written_data
    def initialize(state=nil)
        @written_data = []
        @state = state!=nil ? state : {}
    end

    def load
    end

    def write
        @written_data.push(@state.clone)
    end

    def version_for(name, value=nil)
        if value!=nil
            @state[name] = value
        end

        if !@state.key?(name)
            return nil 
        else
            return @state[name]
        end
    end
end

class MigrationsConfigTests < Test::Unit::TestCase

    def setup
        @c = KumminConfig.new()
    end

    def teardown
        @c.clear
    end

    def test_can_report_version_0
        assert_equal(nil, @c.version())
    end

    def test_can_read_migrations
        m = @c.migrations()
        assert_equal(['FolderMigrations',
                     'InstallJavaMigrations',
                     'MigrationsWithComments',
                     'NoStepsMigrations',
                     'SeveralMigrations',
                     'With3StepsMigrations'], 
                     m.map do |m| m.class.name end) 
    end

    def test_run
        @c.migrate()
    end

end

class ConfigWithVersions < Kummin::Migrator
    attr_reader :versions
    def initialize(state,migrations)
        @versions = FakeVersions.new(state)
        super(:versions=>@versions,:migrations=>migrations)
    end
end

class VersionInfoTests < Test::Unit::TestCase

    def setup
    end

    def test_when_migrating_should_version_accordingly
        @c = ConfigWithVersions.new({}, [FolderMigrations.new])
        @c.migrate()
        expected = [{"kummin"=>'1'},
{"kummin"=>'1', "FolderMigrations"=>'1'},
{"kummin"=>'1', "FolderMigrations"=>'2'}]
        assert_equal(expected,@c.versions.written_data)
    end

    def test_when_existing_state_should_run_only_appropriate_versions
        @c = ConfigWithVersions.new({"kummin"=>'1',"FolderMigrations"=>'1'}, [FolderMigrations.new])
        @c.migrate()
        assert_equal([{"kummin"=>'1', "FolderMigrations"=>'2'}], @c.versions.written_data)
    end
end

class MigrationsTests < Test::Unit::TestCase
    def test_can_report_all_migrate_steps_in_migrations
        steps = FolderMigrations.new.all_steps
        assert_equal(['1','2'], steps)
    end

    def test_will_run_steps_on_up
        f = FolderMigrations.new
        f.up('0','2') 
        assert_equal(['1','2'], f.executed_steps)
    end
    def test_will_run_only_trailing_steps_on_up
        f = FolderMigrations.new
        f.up('1','2')
        assert_equal(['2'], f.executed_steps)
    end

    def test_will_run_steps_in_correct_order
        w = With3StepsMigrations.new
        w.up('0', '3')
        assert_equal(['1','2','3'], w.executed_steps)
    end

    def test_will_upgrade_in_only_one_step
        j = InstallJavaMigrations.new
        j.up('0','3')
        assert_equal(['3'], j.executed_steps)
    end    
end

class JumpToVersionMigrationsTests < Test::Unit::TestCase
    def setup
    end

    def test_when_migrating_jump
        j = InstallJavaMigrations.new
        c = ConfigWithVersions.new({}, [j])
        c.migrate()
        assert_equal(['1.8'], j.executed_steps)
    end
    
end

class SeveralMigrationsTests < Test::Unit::TestCase
    def setup
    end
    def test_all_versions
        s = SeveralMigrations.new
        assert_equal([:step_1, :step_2, :step_9, :step_10, :step_12, :step_12_1, :step_12_2],\
            Kummin.sorted_steps(s,'0',nil))
    end

    def test_when_migrating_jump
        s = SeveralMigrations.new
        c = ConfigWithVersions.new({}, [s])
        c.migrate()
        assert_equal([{:from=>'0', :to=>'12_2'}], s.executed_steps)
    end
end

class ProgramVersionTests < Test::Unit::TestCase
    include Kummin
    def test_version_1_8_should_be_greater_than_0_24
        assert(ProgramVersion.new('1.8')>ProgramVersion.new('0.24'))
    end
    def test_version_1_12_should_be_greater_than_1_11
        assert(ProgramVersion.new('1.12')>ProgramVersion.new('1.11'))
    end
    def test_version_1_12_should_be_greater_than_1_9
        assert(ProgramVersion.new('1.12')>ProgramVersion.new('1.9'))
    end
    def test_version_2_should_be_greater_than_1_9
        assert(ProgramVersion.new('2')>ProgramVersion.new('1.9'))
    end
end

class MigrationsWithComments<  Kummin::StrictVersionMigrations
    attr_reader :executed_steps
    def initialize()
        @executed_steps = []
    end
    def step_10
        @executed_steps.push('10')
    end
    def step_comment_12
        @executed_steps.push('12')
    end
    def step_install_12_1
        @executed_steps.push('12_1')
    end
    def step_uninstall_12_2
        @executed_steps.push('12_2')
    end
    def step_comment2_1
        @executed_steps.push('1')
    end
    def step_comment3_2
        @executed_steps.push('2')
    end
    def step_9
        @executed_steps.push('9')
    end
    def up from, to
        super(from,to)
    end
end

class MigrationsWithCommentsTests < Test::Unit::TestCase
    def setup
    end
    def test_all_versions
        s = MigrationsWithComments.new
        assert_equal([:step_comment2_1, 
                     :step_comment3_2, 
                     :step_9, :step_10, 
                     :step_comment_12, 
                     :step_install_12_1, 
                     :step_uninstall_12_2],\
            Kummin.sorted_steps(s,'0',nil))
    end

    def test_when_migrating_jump
        s = MigrationsWithComments.new
        c = ConfigWithVersions.new({}, [s])
        c.migrate()
        assert_equal(["1", "2", "9", "10", "12", "12_1", "12_2"], s.executed_steps)
    end
end

