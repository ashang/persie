require 'gepub'
require 'nokogiri'
require 'asciidoctor'

require 'time'
require 'fileutils'

require_relative 'pdf'
require_relative 'ui'
require_relative 'epub/gepub_builder_mixin'

module Persie
  class Book

    # Gets base directory.
    attr_reader :base_dir

    # Gets build directory path.
    attr_reader :build_dir

    # Gets theme directory path.
    attr_reader :theme_dir

    # Gets images directory path.
    attr_reader :images_dir

    # Gets tmp directory path.
    attr_reader :tmp_dir

    # Gets master file path.
    attr_reader :master_file

    # Gets book's slug.
    attr_reader :slug

    def initialize(dir)
      @base_dir    = File.expand_path(dir)
      @slug        = File.basename(@base_dir)
      @tmp_dir     = File.join(@base_dir, 'tmp')
      @build_dir   = File.join(@base_dir, 'build')
      @theme_dir   = File.join(@base_dir, 'theme')
      @images_dir  = File.join(@base_dir, 'images')
      @master_file = File.join(@base_dir, 'book.adoc')
    end

    def build_pdf(options = {})
      PDF.new(self, options).build
    end

    def _build_pdf(options={})
      UI.info '=== Build PDF ' << '=' * 58

      unless Dependency.prince_installed?
        UI.error 'Error: PrinceXML not installed'
        UI.info '=' * 72
        exit(11)
      end

      exit_unless_master_file_exists

      prepare_build_dir_for 'pdf'
      prepare_tmp_dir_for 'pdf'

      pdf_dir   = File.join(@build_dir, 'pdf')
      tmp_dir   = File.join(@tmp_dir, 'pdf')
      slug      = File.basename(@base_dir)
      html_file = File.join(tmp_dir, "#{slug}.html")
      pdf_file  = File.join(pdf_dir, "#{slug}.pdf")

      adoc_options = {
        safe: 1,
        backend: 'htmlbook',
        doctype: 'book',
        outfilesuffix: '.html',
        to_dir: tmp_dir,
        to_file: "#{slug}.html",
        attributes: custom_attributes_for('pdf')
      }
      ::Asciidoctor.render_file(@master_file, adoc_options)

      system "prince #{html_file} -o #{pdf_file}"
      if $?.to_i == 0
        UI.confirm 'PDF file created'
        UI.info "  Location: ./build/pdf/#{slug}.pdf"
      else
        UI.error 'Error: Cannot create PDF with PrinceXML'
      end

      UI.info '=' * 72

      nil
    end

    # TODO
    # This method is too long, need refactoring
    def build_epub(options={})

      UI.info '=== Build ePub ' << '=' * 57

      exit_unless_master_file_exists

      prepare_build_dir_for 'epub'
      prepare_tmp_dir_for 'epub'

      epub_dir  = File.join(@build_dir, 'epub')
      tmp_dir   = File.join(@tmp_dir, 'epub')
      slug      = File.basename(@base_dir)
      xhtml_file = "#{slug}.xhtml"

      # 1. Convert the whole book into a single file
      adoc_options = {
        safe: 1,
        backend: 'htmlbook',
        doctype: 'book',
        to_dir: tmp_dir,
        to_file: xhtml_file,
        outfilesuffix: '.xhtml',
        attributes: custom_attributes_for('epub')
      }
      ::Asciidoctor.render_file(@master_file, adoc_options)

      # 2. Generate spine items
      # DO NOT use doc.references[:includes] directly,
      # 'cause it's a Set, no certain ordering.
      # But orders matter in spine, so we use an Asciidoctor extension.
      spine_items = ['cover', 'titlepage', 'nav', 'preamble']
      require_relative 'epub/spine_item_processor'
      doc = ::Asciidoctor.load_file(@master_file, adoc_options)
      spine_items.concat doc.references['spine_items']

      # 3. Split the single file into chunked files
      book_content = File.read(File.join tmp_dir, xhtml_file)
      book = ::Nokogiri::HTML(book_content)

      # Adjust spint items
      has_cover    = book.css('div[data-type="cover"]').size > 0
      has_toc      = book.css('nav[data-type="toc"]').size > 0
      has_preamble = book.css('section[data-type="preamble"]').size > 0
      spine_items.delete('cover')    unless has_cover
      spine_items.delete('toc')      unless has_toc
      spine_items.delete('preamble') unless has_preamble

      top_level_sections = book.css('body > *')

      # stupid check, incase of something goes wrong
      unless top_level_sections.count == spine_items.count
        UI.error 'Count of sections DO NOT equal to spine items count.'
        exit
      end

      sep = '<body data-type="book">'
      tpl_before = book_content.split(sep).first
      tpl_after  = %(</body>\n</html>)

      spine_item_titles = []

      top_level_sections.each_with_index do |node, i|
        # Collect the first h1 heading
        title = node.css('h1:first-of-type').first.inner_text
        spine_item_titles << title

        # Footnotes
        footnotes_div = nil
        footnotes = node.css('span[data-type="footnote"]')
        if footnotes.length > 0
          footnotes_div = generate_footnotes_div(footnotes)
          replace_footnote_with_sup(footnotes)
        end

        # Write to chunked file
        path = File.join(tmp_dir, "#{spine_items[i]}.xhtml")
        File.open(path, 'w') do |f|
          f.puts tpl_before
          f.puts sep
          f.puts node.to_xhtml
          f.puts footnotes_div
          f.puts tpl_after
        end
      end

      # 4. Build ePub
      images_dir = @images_dir
      theme_dir = File.join(@theme_dir, 'epub')

      builder = ::GEPUB::Builder.new do
        extend ::Persie::GepubBuilderMixin

        @doc = doc
        @theme_dir = theme_dir
        @images_dir = images_dir
        @tmp_dir = tmp_dir
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

      epub_path = File.join(epub_dir, "#{slug}.epub")
      builder.generate_epub(epub_path)
      UI.confirm 'ePub file created'
      UI.info "  Location: ./build/epub/#{slug}.epub"

      # 5. Optionally validate epub
      if options.validate?
        UI.info 'Validating...'
        if Dependency.epubcheck_installed?
          system "epubcheck #{epub_path}"
          if $?.to_i == 0
            UI.confirm '  PASS'
          else
            UI.error '  ERROR'
          end
        else
          UI.warning '  epubcheck not installed, skip validation'
        end
      end

      UI.info '=' * 72

      nil
    end

    private

    def exit_unless_master_file_exists
      unless File.exist? @master_file
        UI.error "Error: #{@master_file} not exists"
        UI.info '=' * 72
        exit
      end

      nil
    end

    def prepare_build_dir_for(format)
      format_build_dir = File.join(@build_dir, format)
      unless File.exist? format_build_dir
        FileUtils.mkdir_p format_build_dir
      end
    end

    def prepare_tmp_dir_for(format)
      format_tmp_dir = File.join(@tmp_dir, format)
      unless File.exist? format_tmp_dir
        FileUtils.mkdir_p format_tmp_dir
      end
    end

    def custom_attributes_for(format)
      images_dir = case format
      when 'pdf'
        @images_dir
      when 'epub'
        'images'
      end

      {
        'persie-version' => ::Persie::VERSION,
        'build-dir' => @build_dir,
        'theme-dir' => @theme_dir,
        'ebook-format' => format,
        'imagesdir' => images_dir
      }
    end

    def generate_footnotes_div(footnotes)
      result = ['<div class="footnotes">']
      result << '<ol>'
      footnotes.each_with_index do |fn, i|
        index = i + 1
        result << %(<li id="fn-#{index}" epub:type="footnote">#{fn.inner_text}</li>)
      end
      result << '</ol>'
      result << '</div>'

      result * "\n"
    end

    def replace_footnote_with_sup(footnotes)
      footnotes.each_with_index do |fn, i|
        index = i + 1
        fn.replace(%(<sup><a href="#fn-#{index}">#{index}</a></sup>))
      end

      nil
    end

  end
end
