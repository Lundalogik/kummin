$:.unshift File.dirname(__FILE__)
require 'yaml'
require 'fileutils'
module Kummin
    class ProgramVersion
        include Comparable
        attr_reader :version
        def initialize(version)
            @orig = version
            @version = version.split(/[._]/).map(&:to_i)
        end

        def to_s
            return @orig
        end

        def <=>(otherv)
            return @version <=> otherv.version
        end
    end
    
    class VersionInfo
        attr_reader :filename

        def initialize(filename)
            @filename = filename
            @hash = nil
        end

        def write()
            dirname = File.dirname(@filename)
            if !File.exists?(dirname)
               mkdir_p(dirname)
            end
            File.open(@filename,'w') do |f|
                f.write(YAML::dump(@hash))
            end
        end

        def load()
            if (File.exists?(@filename))
                File.open(@filename,'r') do |f|
                    @hash = YAML::load(f.read)
                end
            else
                @hash = {}
            end
        end

        def version_for(name, val=nil)
            if val!=nil
                @hash[name] = val
            end

            if !@hash.key?(name)
                return nil 
            else
                return @hash[name]
            end
        end
        def clear
            FileUtils.rm_f(@filename)
        end
    end

    def self.step_number_of(step_symbol)
        return step_symbol.to_s.gsub(/step_[_a-zA-Z]*/,'')
    end
    def self.step_version_of(step_symbol)
        return ProgramVersion.new(self.step_number_of(step_symbol))
    end

    def self.all_step_symbols(obj)
        obj.methods.select do |m| 
            m.to_s.start_with?('step_') 
        end
    end

    def self.all_steps(obj)
        return all_step_symbols(obj).map do |m|
            step_number_of(m)
        end
    end

    def self.all_migration_classes()
        classes =
            ObjectSpace.each_object(Class).select do |c|
                c < Migrations && c != StrictVersionMigrations 
            end.map do |c| c.new 
            end.to_a

        classes.sort! do |a,b| a.class.name <=> b.class.name 
        end

        return classes
    end
    def self.sorted_steps(migration, from, to)
        pfrom = ProgramVersion.new(from)
        steps = Kummin.all_step_symbols(migration).select do |s|
            Kummin.step_version_of(s) > pfrom
        end.sort do |a,b|
            Kummin.step_version_of(a) <=> Kummin.step_version_of(b)
        end
        if to!=nil
            pto = ProgramVersion.new(to)
            steps = steps.select do |s|
                Kummin.step_version_of(s) <= pto
            end
        end
        return steps
    end

    class Migrations
    end

    class StrictVersionMigrations < Migrations
        def all_steps
            Kummin.all_steps(self)
        end

        def up from, to #=nil
            #TODO: Parameter 'to'!
            Kummin.sorted_steps(self, from, to).each do |s|
                send s
                yield(Kummin.step_number_of(s)) if block_given?
            end
        end

        def first_version()
            return '0'
        end
    end

    class Migrator
        attr_reader :migrations

        def initialize(params)
            # For mocking
            if params.key? :versions
                @v = params[:versions]
            else
                version_file = params[:version_file]
                @v = VersionInfo.new(version_file)
            end

            @v.load()

            if params.key? :migrations
                @migrations = params[:migrations]
            else
                @migrations = Kummin.all_migration_classes
            end
        end

        def migrate()
            v = @v.version_for('kummin') 
            if v == nil 
                @v.version_for('kummin', '1') 
                @v.write
            end
            @migrations.each do |m|
                v = @v.version_for(m.class.name)
                if v == nil
                    v = m.first_version
                end                
                nxt = m.all_steps.map do |s| ProgramVersion.new(s) end.max
                if nxt == nil 
                    nxt = ProgramVersion.new('0')
                end
                pv = ProgramVersion.new(v)
                if pv < nxt
                    m.up(pv.to_s, nxt.to_s) do |version|
                        @v.version_for(m.class.name, version)
                        @v.write
                    end
                end
            end
        end

        def version(name = nil)
            if !name
                name = 'kummin'
            end
            return @v.version_for(name)
        end
        def clear
            @v.clear 
        end
    end
end
