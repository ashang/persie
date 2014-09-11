require 'thor'
require 'colorize'

require_relative 'book'
require_relative 'version'
require_relative 'generator'

module Persie
  class Cli < ::Thor

    desc 'check', 'Check dependencies'
    def check
      ok = 'installed'.colorize(:green)
      ng = 'not installed'.colorize(:red)

      output = '=== Check dependencies ' << '=' * 49
      output << "\n"

      output << 'PrinceXML: '
      output << (Dependency.prince_installed? ? ok : ng)
      output << "\n"

      output << 'epubcheck: '
      output << (Dependency.epubcheck_installed? ? ok : ng)
      output << "\n"

      output << 'kindlegen: '
      output << (Dependency.kindlegen_installed? ? ok : ng)
      output << "\n"

      output << '=' * 72

      $stdout.puts output
    end

    desc 'new PATH', 'Create a new book'
    def new(path)
      g = ::Persie::Generator.new
      g.destination_root = path
      g.invoke_all
    end

    desc 'build FORMAT', 'Build a ebook format, including pdf, epub, mobi and site'
    method_option :sample, aliases: '-s',
                           type: :boolean,
                           desc: 'Build sample only'
    method_option :validate, aliases: '-c',
                             type: :boolean,
                             desc: 'Validate epub with epubcheck'
    def build(format)
      unless valid_book?
        $stderr.puts 'Not a valid presie project.'.colorize(:red)
        exit 11
      end

      book = ::Persie::Book.new root
      case format
      when 'pdf'
        book.build_pdf(options)
      when 'epub'
        book.build_epub(options)
      when 'mobi'
        book.build_mobi(options)
      else
        $stderr.puts 'Do not support build this formats.'.colorize(:red)
      end
    end

    desc 'version', 'Show the persie version'
    def version
      $stdout.puts "persie #{VERSION}"
    end

    private

    def root
      @root ||= Dir.pwd
    end

    def valid_book?
      File.exist? File.join(root, 'book.adoc')
    end

  end
end
