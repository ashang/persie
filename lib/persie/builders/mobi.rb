require_relative '../builder'

module Persie
  class Mobi < Builder

    def initialize(book, options = {})
      super
      @epub_path = File.join(@book.builds_dir, 'epub', "#{@book.slug}.epub")
    end

    # Builds mobi.
    def build
      UI.info '=== Build mobi ' << '=' * 57

      self.check_dependency
      self.check_epub
      self.generate_mobi

      UI.info END_LINE
    end

    def check_dependency
      unless Dependency.kindlegen_installed?
        UI.error 'kindlegen not installed, termineted!'
        UI.info END_LINE
        exit 41
      end
    end

    # Checks if ePub file generated yet.
    def check_epub
      unless File.exist? @epub_path
        UI.error 'Please generate ePub first'
        UI.info END_LINE
        exit 42
      end
    end

    # Generates mobi file.
    def generate_mobi
      epub = File.basename(@epub_path)

      FileUtils.chdir File.dirname(@epub_path) do
        UI.info 'Converting to mobi...'

        system "kindlegen -c2 #{epub}"
        if $?.to_i == 0
          UI.confirm '    mobi file created'
          UI.info    "    Location: #{self.pdf_path(true)}"
        else
          UI.error '    Error: Cannot create mobi'
          # should not exit here, since it would generate mobi in any case,
          # even there are warnings, like no stylesheet, or no cover.
        end

        mobi_file = "#{@book.slug}.mobi"
        mobi_path = File.join(@book.builds_dir, 'mobi', mobi_file)
        prepare_directory(mobi_path)
        FileUtils.mv(mobi_file, mobi_path)
      end
    end

  end
end
