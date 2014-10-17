require 'nokogiri'
require 'liquid'
require_relative '../builder'

module Persie
  class SingleHTML < Builder

    def initialize(book, options = {})
      super
    end

    # Builds single HTML file.
    def build
      @ui.info '=== Build Single HTML ' << '=' * 50

      self.check_sample
      self.generate_html

      @ui.info END_LINE

      nil
    end

    # Generates single HTML file.
    def generate_html
      html_path = File.join(@book.builds_dir, 'html', 'single' ,'index.html')
      prepare_directory(html_path)

      html = @document.convert
      content = render_layout assemble_payloads(html)

      if content.nil?
        File.write(html_path, html)
      else
        File.write(html_path, content)
      end

      if File.exist? html_path
        @ui.confirm 'HTML created'
        @ui.info    "Location: builds/html/single/index.html"
      else
        @ui.error 'Cannot create HTML'
        @ui.info END_LINE
        exit 52
      end
    end

    private

    def adoc_custom_attributes
      {
        'ebook-format' => 'html',
        'single-page' => true,
        'outfilesuffix' => '.html'
      }
    end

    # Assembles payloads for Liquid to render.
    def assemble_payloads(html)
      root = ::Nokogiri::HTML(html)
      body = root.css('body')
      body.css('> section[data-type="titlepage"]').unlink
      toc = body.css('> nav[data-type="toc"]')
      toc.unlink
      footnotes = body.css('> div.footnotes')
      footnotes.unlink

      attrs = @document.attributes
      custom = {
        'title' => attrs['doctitle'],
        'toc' => toc.to_xhtml,
        'content' => body.to_xhtml,
        'footnotes' => footnotes.to_xhtml,
        'generator' => "persie #{::Persie::VERSION}"
      }

      attrs.merge(custom)
    end

    # Renders ERb layouts.
    def render_layout(payloads)
      path = File.join @book.themes_dir, 'html', "#{format}.html.liquid"

      return nil unless File.exist? path

      tpl = ::Liquid::Template.parse File.read(path)
      tpl.render(payloads)
    end

  end
end
