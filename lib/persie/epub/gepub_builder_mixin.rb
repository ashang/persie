# Most of the contents are steal from asciidoctor-epub3
# Shame on me

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
        file 'epub.css'
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
end
