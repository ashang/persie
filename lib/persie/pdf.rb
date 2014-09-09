require 'asciidoctor'

require_relative 'ui'
require_relative 'dependency'
require_relative 'asciidoctor_ext/sample'

module Persie
  class PDF

    # Gets the AsciiDoctor::Document object.
    attr_reader :document

    def initialize(book, options = {})
      @book = book
      @options = options
      @document = ::Asciidoctor.load_file(@book.master_file, adoc_options)
    end

    # Builds PDF file.
    def build
      UI.info '=== Build PDF ' << '=' * 58

      if sample?
        if @document.sample_sections.size == 0
          UI.warning 'Not setting sample, skip!'
          UI.info '=' * 72
          exit 11
        end
        UI.warning 'Sample only', true
      end

      self.check_dependency
      self.convert_to_html
      self.convert_to_pdf

      UI.info '=' * 72

      nil
    end

    # Checks dependency.
    def check_dependency
      unless Dependency.prince_installed?
        UI.error 'Error: PrinceXML not installed'
        UI.info '=' * 72
        exit 12
      end
    end

    # Gets HTML file path.
    def html_path(relative = false)
      name = sample? ? "#{@book.slug}-sample" : @book.slug
      path = File.join('tmp', 'pdf', "#{name}.html")
      return path if relative

      File.join(@book.base_dir, path)
    end

    # Gets PDF file path.
    def pdf_path(relative = false)
      name = sample? ? "#{@book.slug}-sample" : @book.slug
      path = File.join('build', 'pdf', "#{name}.pdf")
      return path if relative

      File.join(@book.base_dir, path)
    end

    # Converts AsciiDoc document to HTML, and writes to a file.
    def convert_to_html
      UI.info 'Converting to HTML...'
      html = @document.convert
      File.open(self.html_path, 'w') do |f|
        f.puts html
      end
      UI.confirm '    HTMl file created'
      UI.info    "    Location: #{self.html_path(true)}", true
    end

    # Converts HTML to PDF with PrinceXML.
    def convert_to_pdf
      UI.info 'Converting to PDF...'
      system "prince #{self.html_path} -o #{self.pdf_path}"
      if $?.to_i == 0
        UI.confirm '    PDF file created'
        UI.info    "    Location: #{self.pdf_path(true)}"
      else
        UI.error '    Error: Cannot create PDF with PrinceXML'
      end
    end

    private

    # Options passed into AsciiDoctor loader.
    def adoc_options
      {
        safe: 1,
        backend: 'htmlbook',
        doctype: 'book',
        outfilesuffix: '.html',
        header_footer: true,
        attributes: adoc_attributes
      }
    end

    # Attributes as in AsciiDoctor loader option.
    def adoc_attributes
      attrs = {
        'persie-version' => VERSION,
        'build-dir' => @book.build_dir,
        'theme-dir' => @book.theme_dir,
        'ebook-format' => 'pdf',
        'imagesdir' => @book.images_dir
      }

      attrs['is-sample'] = true if sample?

      attrs
    end

    def sample?
      return true if @options.has_key? 'sample'
      false
    end

  end
end
