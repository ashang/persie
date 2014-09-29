require 'nokogiri'

require 'time'

require_relative '../builder'

module Persie
  module GepubBuilderMixin

    FromHtmlSpecialCharsMap = {
      '&lt;' => '<',
      '&gt;' => '>',
      '&amp;' => '&'
    }
    FromHtmlSpecialCharsRx = /(?:#{FromHtmlSpecialCharsMap.keys * '|'})/
    WordJoinerRx = [65279].pack 'U*'
    CsvDelimiterRx = /\s*,\s*/

    def sanitized_title(title, target = :plain)
      return (@doc.attr 'untitled-label') unless @doc.header?

      builder = self

      title = case target
      when :attribute_cdata
        builder.sanitize(title).gsub('"', '&quot;')
      when :element_cdata
        builder.sanitize(title)
      when :pcdata
        title
      when :plain
        builder.sanitize(title).gsub(FromHtmlSpecialCharsRx, FromHtmlSpecialCharsMap)
      end

      title.gsub WordJoinerRx, ''
    end

    def sanitize(text)
      if text.include?('<')
        text.gsub(::Asciidoctor::XmlSanitizeRx, '').tr_s(' ', ' ').strip
      else
        text
      end
    end

    def authors
      if (auts = @doc.attr 'authors')
        auts.split(CsvDelimiterRx)
      else
        []
      end
    end

    def add_theme_assets
      resources(workdir: @theme_dir) do
        file 'epub.css' if File.exist?('epub.css')
        glob 'fonts/*.*'
      end
    end

    def add_cover_image
      image = @doc.attr('epub-cover-image', 'cover.png')
      image = File.basename(image) # incase you set this a path

      if File.exist? image
        resources(workdir: @theme_dir) do
          cover_image image
        end
      end
    end

    def add_images
      resources(workdir: @images_dir) do
        glob '*.*'
      end
    end

    def add_content
      builder = self
      spine_items = @spine_items
      spine_item_titles = @spine_item_titles
      resources(workdir: @tmp_dir) do
        nav 'nav.xhtml' if @has_toc

        ordered do
          spine_items.each_with_index do |item, i|
            file "#{item}.xhtml"
            heading builder.sanitized_title(spine_item_titles[i])
          end
        end
      end
    end

  end

  class Epub < Builder

    # these are not using `include' directive
    SPECIAL_SPINE_ITEMS = ['cover', 'titlepage', 'nav']

    # Gets/Sets spine items.
    attr_accessor :spine_items

    # Gets/Sets spine items's titles.
    attr_accessor :spine_item_titles

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
      @ui.info '=== Build ePub ' << '=' * 57

      self.check_sample
      self.convert_to_single_xhtml
      self.generate_spine_items
      self.chunk
      self.generate_epub
      self.validate

      @ui.info END_LINE
    end

    # Converts to single XHTML file.
    def convert_to_single_xhtml
      @ui.info 'Converting to XHTML...'
      xhtml = @document.convert
      prepare_directory(self.xhtml_path)
      File.write(self.xhtml_path, xhtml)
      @ui.confirm '    XHTMl file created'
      @ui.info    "    Location: #{self.xhtml_path(true)}\n"
    end

    # Generates spine items.
    def generate_spine_items
      register_spine_item_processor

      # Re-loading the master file
      doc = ::Asciidoctor.load_file(@book.master_file, adoc_options)
      @spine_items.concat SPECIAL_SPINE_ITEMS
      @spine_items.concat doc.references['spine_items']

      @spine_items
    end

    # Chucks single XHTML file to multiple XHTML files.
    def chunk
      @ui.info 'Chunking files...'

      content = File.read(self.xhtml_path)
      root = ::Nokogiri::HTML(content)

      # Adjust spint items
      @has_cover    = root.css('div[data-type="cover"]').size > 0
      @has_toc      = root.css('nav[data-type="toc"]').size > 0
      self.spine_items.delete('cover')    unless @has_cover
      self.spine_items.delete('toc')      unless @has_toc

      correct_nav_href(root)

      top_level_sections = resolve_top_level_sections(root)

      # stupid check, incase of something went wrong
      unless top_level_sections.count == self.spine_items.count
        @ui.error '    Count of sections DO NOT equal to spine items count.'
        @ui.error '    Terminated!'
        if @options.debug?
          @ui.info 'sections count: ' + top_level_sections.count
          @ui.info 'spine_items: ' + self.spine_items.inspect
        end
        @ui.info  END_LINE
        exit 31
      end

      sep = '<body data-type="book">'
      tpl_before = content.split(sep).first
      tpl_after  = %(</body>\n</html>)

      top_level_sections.each_with_index do |node, i|
        # Collect the first h1 heading
        title = node.css('h1:first-of-type').first.inner_text
        @spine_item_titles << title

        # Footnotes
        footnotes_div = generate_footnotes(node)

        # Write to chunked file
        path = File.join(@tmp_dir, "#{self.spine_items[i]}.xhtml")
        File.open(path, 'w') do |f|
          f.puts tpl_before
          f.puts sep
          f.puts node.to_xhtml
          f.puts footnotes_div
          f.puts tpl_after
        end
      end

      @ui.confirm '    Done\n'
    end

    # Generates ePub file.
    def generate_epub
      doc = @document
      tmp_dir = @tmp_dir
      theme_dir = @theme_dir
      images_dir = @book.images_dir
      has_toc = @has_toc
      spine_items = self.spine_items
      spine_item_titles = self.spine_item_titles

      @ui.info 'Building ePub...'

      builder = ::GEPUB::Builder.new do
        extend GepubBuilderMixin

        @doc = doc
        @tmp_dir = tmp_dir
        @theme_dir = theme_dir
        @images_dir = images_dir
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
      @ui.confirm '    ePub file created'
      @ui.info    "    Location: #{self.epub_path(true)}"
    end

    # Validates ePub file, optionally.
    def validate
      if @options.validate?
        @ui.info "\nValidating..."
        if Dependency.epubcheck_installed?
          system "epubcheck #{epub_path}"
          if $?.to_i == 0
            @ui.confirm '    PASS'
          else
            @ui.error '    ERROR'
          end
        else
          @ui.warning '    epubcheck not installed, skip validation'
        end
      end
    end

    # Gets XHTML file path.
    def xhtml_path(relative = false)
      name = sample? ? "#{@book.slug}-sample" : @book.slug
      path = File.join('tmp', 'epub', "#{name}.html")
      return path if relative

      File.join(@book.base_dir, path)
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

    # Corrects navigation items' href.
    #
    # Example:
    #   href="#id" => href="path.xhtml#id"
    def correct_nav_href(node)
      return unless (ols = node.css('nav[data-type="toc"]> ol')).size > 0

      spine_items_dup = self.spine_items.dup
      SPECIAL_SPINE_ITEMS.each { |i| spine_items_dup.delete(i) }

      top_level_lis = ols.first.css('> li')
      j = 0
      top_level_lis.each do |li|
        if li['data-type'] == 'part'
          first_a = li.css('> a').first
          first_a_href = first_a['href']
          first_a['href'] = "#{spine_items_dup[j]}.xhtml#{first_a_href}"
          if (li_ols = li.css('> ol')).size > 0
            li_ol = li_ols.first
            li_ol.css('> li').each do |lli|
              j += 1
              lli.css('a').each do |a|
                old_href = a['href']
                a['href'] = "#{spine_items_dup[j]}.xhtml#{old_href}"
              end
            end
            j += 1
          end
        else
          li.css('a').each do |a|
            old_href = a['href']
            a['href'] = "#{spine_items_dup[j]}.xhtml#{old_href}"
          end
          j += 1
        end
      end
    end


    # Resolves top level sections.
    #
    # When there are parts, takes sections within each part out.
    def resolve_top_level_sections(node)
      if (parts = node.css('body > div[data-type="part"]')).size > 0
        parts.each do |part|
          sections = part.css('> section')
          sections.each do |sect|
            part.delete sect
          end
          part.add_next_sibling(sections)
        end
      end

      node.css('body > *')

    end

    # Generates footnotes for one node.
    def generate_footnotes(node)
      footnotes_div = nil
      footnotes = node.css('span[data-type="footnote"]')
      if footnotes.length > 0
        footnotes_div = generate_footnotes_div(footnotes)
        replace_footnote_with_sup(footnotes)
      end

      footnotes_div
    end

    # Generate a footnotes div element.
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
