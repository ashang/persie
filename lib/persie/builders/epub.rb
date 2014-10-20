require 'time'

require_relative '../gepub_ext'
require_relative '../builder'
require_relative '../chunkable'

module Persie

  class Epub < Builder

    include Chunkable

    def initialize(book, options = {})
      super
      @tmp_dir = File.join(book.tmp_dir, 'epub')
      @theme_dir = File.join(book.themes_dir, 'epub')
      @build_dir = File.join(book.builds_dir, 'epub')
      @spine_items = []
      @spine_item_titles = []
    end

    # Builds ePub.
    def build
      info '=== Build ePub ' << '=' * 57

      self.before_build
      self.check_sample
      self.convert_to_single_html
      self.generate_spine_items
      self.chunk
      self.generate_epub
      self.validate
      self.after_build

      info END_LINE
    end

    # Generates ePub file.
    def generate_epub
      doc = @document
      tmp_dir = @tmp_dir
      theme_dir = @theme_dir
      has_toc = @has_toc
      spine_items = self.spine_items
      spine_item_titles = self.spine_item_titles

      info 'Building ePub...'

      builder = ::GEPUB::Builder.new do
        extend GepubBuilderMixin

        @doc = doc
        @tmp_dir = tmp_dir
        @theme_dir = theme_dir
        @has_toc = has_toc
        @spine_items = spine_items
        @spine_item_titles = spine_item_titles

        language doc.attr('lang', 'en')
        id 'pub-language'

        scheme = doc.attr('epub-identifier-scheme', 'uuid').downcase
        scheme = 'uuid' unless ['uuid', 'isbn'].include? scheme
        unique_identifier doc.attr(scheme), 'pub-identifier', scheme

        title sanitized_title(doc.doctitle)
        id 'pub-title'

        if doc.attr? 'publisher'
          publisher(publisher_name = doc.attr('publisher'))
          # marc role: Book producer (see http://www.loc.gov/marc/relators/relaterm.html)
          creator doc.attr('producer', publisher_name), 'bkp'
        else
          # Use producer as both publisher and producer if publisher isn't specified
          if doc.attr? 'producer'
            producer_name = doc.attr('producer')
            publisher producer_name
            # marc role: Book producer (see http://www.loc.gov/marc/relators/relaterm.html)
            creator producer_name, 'bkp'
          # Use author as creator if both publisher or producer are absent
          elsif doc.attr? 'author'
            # marc role: Author (see http://www.loc.gov/marc/relators/relaterm.html)
            creator doc.attr('author'), 'aut'
          end
        end

        if doc.attr? 'creator'
          # marc role: Creator (see http://www.loc.gov/marc/relators/relaterm.html)
          creator doc.attr('creator'), 'cre'
        else
          # marc role: Manufacturer (see http://www.loc.gov/marc/relators/relaterm.html)
          creator 'persie', 'mfr'
        end

        contributors(*authors) unless authors.empty?

        if doc.attr? 'revdate'
          real_date = Time.parse(doc.attr 'revdate').iso8601
          date real_date
        else
          date Time.now.strftime('%Y-%m-%dT%H:%M:%SZ')
        end

        if doc.attr? 'description'
          description(doc.attr 'description')
        end

        if doc.attr? 'copyright'
          rights(doc.attr 'copyright')
        end

        add_theme_assets
        add_cover_image
        add_images
        add_content
      end

      prepare_directory(self.epub_path)
      builder.generate_epub(self.epub_path)
      confirm '    ePub file created'
      info    "    Location: #{self.epub_path(true)}"
    end

    # Validates ePub file, optionally.
    def validate
      if @options.validate?
        info "Validating..."
        if Dependency.epubcheck_installed?
          system "epubcheck #{epub_path}"
          if $?.to_i == 0
            confirm '    PASS'
          else
            error '    ERROR'
          end
        else
          warning '    epubcheck not installed, skip validation'
        end
      end
    end

    # Gets ePub file path.
    def epub_path(relative = false)
      name = sample? ? "#{@book.slug}-sample" : @book.slug
      path = File.join('builds', 'epub', "#{name}.epub")
      return path if relative

      File.join(@book.base_dir, path)
    end

    private

    def adoc_custom_attributes
      {
        'imagesdir' => 'images',
        'ebook-format' => 'epub',
        'outfilesuffix' => '.xhtml'
      }
    end

  end
end
