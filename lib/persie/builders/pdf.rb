require 'nokogiri'

require_relative '../builder'

module Persie
  class PDF < Builder

    def initialize(book, options = {})
      super
    end

    # Builds PDF.
    def build
      @ui.info '=== Build PDF ' << '=' * 58

      self.check_dependency
      self.check_sample

      self.convert_to_html
      self.restart_page_number
      self.convert_to_pdf

      @ui.info END_LINE

      nil
    end

    # Checks dependency.
    def check_dependency
      unless Dependency.prince_installed?
        @ui.error 'Error: PrinceXML not installed'
        @ui.info END_LINE
        exit 22
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
      path = File.join('builds', 'pdf', "#{name}.pdf")
      return path if relative

      File.join(@book.base_dir, path)
    end

    # Converts AsciiDoc document to HTML, and writes to a file.
    def convert_to_html
      @ui.info 'Converting to HTML...'
      html = @document.convert
      prepare_directory(self.html_path)
      File.write(self.html_path, html)
      @ui.confirm '    HTMl file created'
      @ui.info    "    Location: #{self.html_path(true)}\n"
    end

    # Restart PDF page number.
    def restart_page_number
      content = File.read(self.html_path)
      root = ::Nokogiri::HTML(content)

      # Has parts
      if (parts = root.css('body > div[data-type="part"]')).size > 0
        add_class(parts.first, 'restart_page_number')
      # No parts, but has chapters
      elsif (chapters = root.css('body > section[data-type="chapter"]')).size > 0
        add_class(chapters.first, 'restart_page_number')
      end

      File.write(self.html_path, root.to_xhtml)
    end

    # Converts HTML to PDF with PrinceXML.
    def convert_to_pdf
      @ui.info 'Converting to PDF...'
      prepare_directory(self.pdf_path)
      system "prince #{self.html_path} -o #{self.pdf_path}"
      if $?.to_i == 0
        @ui.confirm '    PDF file created'
        @ui.info    "    Location: #{self.pdf_path(true)}"
      else
        @ui.error '    Error: Cannot create PDF with PrinceXML'
        @ui.info END_LINE
        exit 23
      end
    end

    private

    def adoc_custom_attributes
      {
        'ebook-format' => 'pdf',
        'outfilesuffix' => '.html'
      }
    end

    # Add a class to a element.
    def add_class(el, cls)
      classes = el['class'].to_s.split(/\s+/)
      el['class'] = classes.push(cls).uniq.join " "
    end

  end
end
