require 'colorize'

module Persie
  module UI

    def self.info(msg, newline=nil)
      $stdout.puts msg
      $stdout.puts if newline
    end

    def self.confirm(msg, newline=nil)
      $stdout.puts msg.colorize(:green)
      $stdout.puts if newline
    end

    def self.error(msg, newline=nil)
      $stderr.puts msg.colorize(:red)
      $stderr.puts if newline
    end

    def self.warning(msg, newline=nil)
      $stdout.puts msg.colorize(:yellow)
      $stdout.puts if newline
    end

  end
end
