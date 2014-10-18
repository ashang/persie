require_relative '../builder'
require_relative '../chunkable'

module Persie
  class MultipleHTMLs < Builder

    include Chunkable

    def initialize(book, options = {})
      super
      @spine_items = []
      @spine_item_titles = []
    end

    # Builds multiple HTML files.
    def build
      @ui.info '=== Build Mutiple HTML ' << '=' * 49

      self.check_sample
      self.convert_to_single_html
      self.generate_spine_items
      self.chunk

      @ui.info 'Location: builds/html/multiple/'
      @ui.info END_LINE

      nil
    end

    private

    def adoc_custom_attributes
      {
        'ebook-format' => 'html',
        'multiple-pages' => true,
        'outfilesuffix' => '.html'
      }
    end

    # Assembles payloads for Liquid to render.
    def assemble_payloads
      attrs = @document.attributes
      custom = {
        'title' => attrs['doctitle'],
        'generator' => "persie #{::Persie::VERSION}"
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
