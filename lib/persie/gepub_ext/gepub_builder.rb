require_relative 'ibooks_fonts'

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

    def add_ibooks_version
      rev = @doc.attr 'revnumber', '1.0'
      if rev !~ /\d{1,4}\.\d{1,4}(\.\d{1,4})?/
        rev = '1.0'
      end

      ibooks_version rev
    end

    def add_ibooks_specified_fonts
      ibooks_specified_fonts true
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

      resources(workdir: @theme_dir) do
        cover_image image if File.exist? image
      end

    end

    def add_images
      resources(workdir: @base_dir) do
        glob 'images/**/*.*'
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
end
