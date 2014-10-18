require_relative '../builder'

module Persie
  class Mobi < Builder

    def initialize(book, options = {})
      super
    end

    # Builds mobi.
    def build
      info '=== Build mobi ' << '=' * 57

      self.check_dependency
      check_sample
      self.check_epub
      self.generate_mobi

      info END_LINE
    end

    def check_dependency
      unless Dependency.kindlegen_installed?
        error 'kindlegen not installed, termineted!'
        info END_LINE
        exit 41
      end
    end

    # Checks if ePub file generated yet.
    def check_epub
      unless File.exist? self.epub_path
        sample = sample? ? 'sample ' : nil
        error "Please generate #{sample}ePub first"
        info END_LINE
        exit 42
      end
    end

    # Generates mobi file.
    def generate_mobi
      FileUtils.chdir File.dirname(self.epub_path) do
        info 'Converting to mobi...'

        system "kindlegen -c2 #{self.epub_path(true)}"

        mobi_file = File.basename(self.mobi_path)
        if File.exist? mobi_file
          prepare_directory(self.mobi_path)
          FileUtils.mv(mobi_file, self.mobi_path)

          confirm '    mobi file created'
          info    "    Location: #{self.mobi_path(true)}"
        else
          error '    Can not create mobi'
          info END_LINE
          exit 43
        end
      end
    end

    # Gets ePub file path.
    def epub_path(relative=false)
      name = sample? ? "#{@book.slug}-sample" : @book.slug
      return "#{name}.epub" if relative

      File.join(@book.builds_dir, 'epub', "#{name}.epub")
    end

    # Gets mobi file path.
    def mobi_path(relative = false)
      name = sample? ? "#{@book.slug}-sample" : @book.slug
      path = File.join('builds', 'mobi', "#{name}.mobi")
      return path if relative

      File.join(@book.base_dir, path)
    end

  end
end
