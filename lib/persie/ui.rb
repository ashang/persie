require 'colorize'

module Persie
  module UI

    def info(msg, new_line=nil)
      $stdout.puts msg
      $stdout.puts if new_line
    end

    def confirm(msg, new_line=nil)
      $stdout.puts msg.colorize(:green)
      $stdout.puts if new_line
    end

    def error(msg, new_line=nil)
      $stderr.puts msg.colorize(:red)
      $stderr.puts if new_line
    end

    def warning(msg, new_line=nil)
      $stdout.puts msg.colorize(:yellow)
      $stdout.puts if new_line
    end

  end
end
