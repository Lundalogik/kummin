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

    class StepHandler
        def step_number_of(step_symbol)
            return step_symbol.to_s.gsub(/step_/,'').to_i
        end
        def all_step_symbols(obj)
            obj.methods.select do |m| 
                m.to_s.start_with?('step_') 
            end
        end
        def all_steps(obj)
            return all_step_symbols(obj).map do |m|
                step_number_of(m)
            end
        end
    end
    
    $step_handler = StepHandler.new

    class Migrations
    end

    class StrictVersionMigrations < Migrations
        def all_steps
            return $step_handler.all_steps(self)
        end

        def up from, to
            $step_handler.all_step_symbols(self).select do |s|
                $step_handler.step_number_of(s) > from
            end.sort do |a,b|
                $step_handler.step_number_of(a)<=> $step_handler.step_number_of(b)
            end.each do |s|
                send s
            end
        end
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
