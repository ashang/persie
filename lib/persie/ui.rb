require 'colorize'

module Persie
  class UI

    def initialize(options= {})
      @test_mode = options.has_key?(:test) && options[:test] === true
    end

    def info(msg)
      $stdout.puts msg unless @test_mode
    end

    def confirm(msg)
      $stdout.puts msg.colorize(:green) unless @test_mode
    end

    def error(msg)
      $stderr.puts msg.colorize(:red) unless @test_mode
    end

    def warning(msg)
      $stdout.puts msg.colorize(:yellow) unless @test_mode
    end

  end
end
