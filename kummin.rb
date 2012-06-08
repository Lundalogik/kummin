$:.unshift File.dirname(__FILE__)
require 'yaml'
require 'fileutils'
module Kummin

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

        def version_for(tp, val=nil)
            if val!=nil
                @hash[tp] = val
            end

            if !@hash.key?(tp)
                return 0
            else
                return @hash[tp]
            end
        end

    end

    class Migrations
        def all_steps
            return self.methods.select do |m| 
                m.to_s.start_with?('step_') 
            end.map do |m|
                m.to_s.gsub(/step_/,'')
            end
        end
    end

    class StrictVersionMigrations < Migrations

    end

    class JumpVersionMigrations < Migrations
        
    end

    class Configuration
        attr_reader :migrations
        def initialize(params)
            @version_file = params[:version_file]
            @v = VersionInfo.new(@version_file)
            @v.load()

            @migrations = ObjectSpace.each_object(Class).select do |c|
                c < Migrations && c != StrictVersionMigrations && c != JumpVersionMigrations
            end.to_a.sort! do |a,b| a.name <=> b.name end
        end

        def load_migrations
        end

        def migrate()
            v = @v.version_for('kummin') 
            if v == 0 
                @v.version_for('kummin', 1) 
                @v.write
            end
            @migrations.each do |m|
                v = @v.version_for(m.name)
                nxt = v+1
                m.new.up(v, nxt)
                @v.version_for(m.name, nxt)
            end
            @v.write
        end

        def down()

        end

        def version(tp=nil)
            if !tp
                tp = 'kummin'
            end
            return @v.version_for(tp)
        end
        def clear
            FileUtils.rm_f(@version_file)
        end
    end
end
