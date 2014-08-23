require 'thor'

module Persie
  class Cli < ::Thor

    desc 'new PATH', 'Create a new book'
    def new(path)
      generator = ::Persie::Generator.new
      generator.destination_root = path
      generator.invoke_all
    end

    desc 'build FORMAT', 'Build a ebook format, including pdf, epub, mobi and site'
    method_option :debug, aliases: '-d',
                          type: :boolean,
                          desc: 'Turn on debug mode'
    def build(format)
      book = ::Persie::Book.new Dir.pwd
      case format
      when 'pdf'
        book.build_pdf(options)
      end
    end

    desc 'version', 'Show the persie version'
    def version
      puts ::Persie::VERSION
    end

    private

    def book_root
      @root ||= Dir.pwd
    end

  end
end
