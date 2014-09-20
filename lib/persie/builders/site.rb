require 'nokogiri'

require_relative '../builder'

module Persie
  class Site < Builder

    def initialize(book, options = {})
      super
    end

    # Builds a website.
    def build
      UI.info '=== Build site ' << '=' * 57

      if @options.multiple?
        self.build_chunked
        return nil
      end

      self.build_single

      UI.info END_LINE
    end

    def build_chunked

    end

    # Builds single file website.
    def build_single
      UI.warning 'Single page', true

      html_path = File.join(@book.builds_dir, 'site', 'single' ,'index.html')
      prepare_directory(html_path)

      html = @document.convert
      File.write(html_path, html)

      if File.exist? html_path
        UI.confirm 'Site created'
        UI.info    "Location: site/single/index.html"
      else
        UI.error 'Cannot create site'
        UI.info END_LINE
        exit 52
      end
    end

    private

    def adoc_custom_options
      {
        outfilesuffix: '.html'
      }
    end

    def adoc_custom_attributes
      {
        'ebook-format' => 'site'
      }
    end

  end
end
