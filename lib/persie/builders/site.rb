require 'nokogiri'
require 'liquid'
require_relative '../builder'

module Persie
  class Site < Builder

    def initialize(book, options = {})
      super
    end

    # Builds a website.
    def build
      @ui.info '=== Build site ' << '=' * 57

      if @options.multiple?
        self.build_multiple
        return nil
      end

      self.build_single

      @ui.info END_LINE

      nil
    end

    def build_multiple
      @ui.warning "Multiple pages\n"

      @ui.warning 'Not Implemented!'
    end

    # Builds single file website.
    def build_single
      @ui.warning "Single page\n"

      html_path = File.join(@book.builds_dir, 'site', 'single' ,'index.html')
      prepare_directory(html_path)

      html = @document.convert
      content = render_layout_of('single', assemble_payloads(html))

      if content.nil?
        File.write(html_path, html)
      else
        File.write(html_path, content)
      end

      if File.exist? html_path
        @ui.confirm 'Site created'
        @ui.info    "Location: site/single/index.html"
      else
        @ui.error 'Cannot create site'
        @ui.info END_LINE
        exit 52
      end
    end

    private

    def adoc_custom_attributes
      {
        'ebook-format' => 'site',
        'single-page' => @options.multiple? ? false : true,
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
        'generator' => "persie ::Persie::VERSION"
      }

      attrs.merge(custom)
    end

    # Renders ERb layouts of `single' or `multiple'.
    def render_layout_of(format, payloads)
      unless ['single', 'multipe'].include? format
        @ui.error "ONLY can render layout for `single' or `multiple'"
        @ui.info END_LINE
        exit 53
      end

      # Site templates stored in `themes/site/' folder
      path = File.join @book.themes_dir, 'site', "#{format}.html.liquid"

      return nil unless File.exist? path

      tpl = ::Liquid::Template.parse File.read(path)
      tpl.render(payloads)
    end

  end
end
