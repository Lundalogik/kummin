$:.unshift File.dirname(__FILE__)
require 'yaml'
require 'fileutils'
module Kummin

    class ProgramVersion
        include Comparable
        attr_reader :version
        def initialize(version)
            @version = version
        end

        def to_s
            return @version
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
        return step_symbol.to_s.gsub(/step_/,'').to_i
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

    class Migrations
    end

    class StrictVersionMigrations < Migrations
        def all_steps
            return Kummin.all_steps(self)
        end

        def up from, to, &block #=nil
            Kummin.all_step_symbols(self).select do |s|
                Kummin.step_number_of(s) > from
            end.sort do |a,b|
                Kummin.step_number_of(a)<=> Kummin.step_number_of(b)
            end.each do |s|
                send s
                if block!=nil
                    block.call( Kummin.step_number_of(s))
                end
            end
        end

        def first_version()
            return 0
        end
    end

    class Configuration
        attr_reader :migrations
        def initialize(params)
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
                @migrations = ObjectSpace.each_object(Class).select do |c|
                    c < Migrations && c != StrictVersionMigrations 
                end.map do |c| c.new end.to_a
            end
            @migrations.sort! do |a,b| a.class.name <=> b.class.name end
        end

        def migrate()
            v = @v.version_for('kummin') 
            if v == nil 
                @v.version_for('kummin', 1) 
                @v.write
            end
            @migrations.each do |m|
                v = @v.version_for(m.class.name)
                if v == nil
                    v = m.first_version
                end                
                nxt = m.all_steps.max
                if v<nxt
                    m.up(v, nxt) do |version|
                        @v.version_for(m.class.name, version)
                        @v.write
                    end
                end
            end
        end

        def down()

        end

        def version(name=nil)
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
