require 'nokogiri'

module Persie
  module Chunkable

    # these are not using `include' directive
    SPECIAL_SPINE_ITEMS = ['cover', 'titlepage', 'nav']

    # Gets/Sets spine items.
    attr_accessor :spine_items

    # Gets/Sets spine items's titles.
    attr_accessor :spine_item_titles

    # Converts to single HTML file.
    def convert_to_single_html
      info 'Converting to HTML...'
      format = @document.attr('ebook-format')
      html = @document.convert
      prepare_directory self.html_path(format)
      File.write self.html_path(format), html
      confirm '    HTMl file created'
      info    "    Location: #{self.html_path(format, true)}\n"
    end

    # Generates spine items.
    def generate_spine_items
      register_spine_item_processor

      # Re-load the master file
      doc = ::Asciidoctor.load_file(@book.master_file, adoc_options)
      @spine_items.concat SPECIAL_SPINE_ITEMS
      @spine_items.concat doc.references['spine_items']

      # no need cover page and titlepage in HTML format
      @spine_items.shift(2) if @document.attr('ebook-format') == 'html'

      @spine_items
    end

    # Chucks single HTML file to multiple HTML files.
    def chunk
      info 'Chunking files...'

      format = @document.attr('ebook-format')
      content = File.read self.html_path(format)
      root = ::Nokogiri::HTML(content)

      # Adjust spint items
      @has_cover    = root.css('div[data-type="cover"]').size > 0
      @has_toc      = root.css('nav[data-type="toc"]').size > 0
      self.spine_items.delete('cover') unless @has_cover
      self.spine_items.delete('toc')   unless @has_toc

      correct_nav_href(root)

      top_level_sections = resolve_top_level_sections(root)

      # stupid check, incase of something went wrong
      if @options.debug?
        info 'sections count: ' << top_level_sections.count.inspect
        info 'spine_items: ' << self.spine_items.inspect
      end

      unless top_level_sections.count == self.spine_items.count
        error '    Count of sections DO NOT equal to spine items count.'
        error '    Terminated!'
        info  '=' * 72
        exit 31
      end

      sep = '<body data-type="book">'
      before = content.split(sep).first
      after  = %(</body>\n</html>)

      # Collect the first h1 heading first
      top_level_sections.each_with_index do |node, i|
        title = if (i == 0 && @has_cover) # cover page don't have title
          @document.attr('cover-page-title', 'Cover')
        else
          node.css('h1:first-of-type').first.inner_text
        end
        @spine_item_titles << title
      end

      top_level_sections.each_with_index do |node, i|
        # Footnotes
        footnotes_div = generate_footnotes(node)

        # Write to chunked file
        ext = @document.attr('outfilesuffix', '.html')
        to_dir = if format == 'epub'
          @tmp_dir
        else
          File.join @book.builds_dir, 'html', 'multiple'
        end
        path = File.join(to_dir, "#{self.spine_items[i]}#{ext}")
        prepare_directory(path)
        combined = [before, sep, node.to_xhtml, footnotes_div, after] * "\n"

        # use only when building multiple html files
        layout = File.join @book.themes_dir, 'html', 'multiple.html.liquid'

        chunked_content = if format == 'epub'
          combined
        elsif (format == 'html' && !File.exist?(layout))
          combined
        else
          require 'liquid'
          tpl = ::Liquid::Template.parse File.read(layout)

          if i == 0
            prev_url   = nil
            prev_title = nil
          else
            prev_url   = "#{@spine_items[i - 1]}#{ext}"
            prev_title = @spine_item_titles[i - 1]
          end

          if (j = i + 1) == @spine_items.count
            next_url   = nil
            next_title = nil
          else
            next_url   = "#{@spine_items[j]}#{ext}"
            next_title = @spine_item_titles[j]
          end

          payloads = assemble_payloads.merge 'page_title' => @spine_item_titles[i],
                                             'content' => node.to_xhtml,
                                             'footnotes' => footnotes_div,
                                             'prev_url' => prev_url,
                                             'next_url' => next_url,
                                             'prev_title' => prev_title,
                                             'next_title' => next_title

          tpl.render(payloads)
        end

        File.write path, chunked_content
      end

      confirm "    Done"
    end

    # Gets XHTML file path.
    def html_path(format, relative = false)
      name = sample? ? "#{@book.slug}-sample" : @book.slug
      path = File.join('tmp', format, "#{name}.html")
      return path if relative

      File.join(@book.base_dir, path)
    end

    private

    # Corrects navigation items' href.
    #
    # Example:
    #   href="#id" => href="path.xhtml#id"
    def correct_nav_href(node)
      # return early if no table of contents
      return nil unless (ols = node.css('nav[data-type="toc"]> ol')).size > 0

      spine_items_dup = self.spine_items.dup
      SPECIAL_SPINE_ITEMS.each { |i| spine_items_dup.delete(i) }

      ext = @document.attr('outfilesuffix', '.html')
      top_level_lis = ols.first.css('> li')
      j = 0
      top_level_lis.each do |li|
        if li['data-type'] == 'part'
          first_a = li.css('> a').first
          first_a_href = first_a['href']
          first_a['href'] = "#{spine_items_dup[j]}#{ext}#{first_a_href}"
          if (li_ols = li.css('> ol')).size > 0
            li_ol = li_ols.first
            li_ol.css('> li').each do |lli|
              j += 1
              lli.css('a').each do |a|
                old_href = a['href']
                a['href'] = "#{spine_items_dup[j]}#{ext}#{old_href}"
              end
            end
            j += 1
          end
        else
          li.css('a').each do |a|
            old_href = a['href']
            a['href'] = "#{spine_items_dup[j]}#{ext}#{old_href}"
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

      # return a nodeset, contains all top level sections
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
      epub_type = if @document.attr('ebook-format') == 'epub'
        %( epub:type="footnote")
      else
        nil
      end
      result = ['<div class="footnotes">']
      result << '<ol>'
      footnotes.each_with_index do |fn, i|
        index = i + 1
        ref = %( <a href="#fn-ref-#{index}">&#8617;</a>)
        result << %(<li id="fn-#{index}"#{epub_type}>#{fn.inner_html}#{ref}</li>)
      end
      result << '</ol>'
      result << '</div>'

      result * "\n"
    end

    def replace_footnote_with_sup(footnotes)
      footnotes.each_with_index do |fn, i|
        index = i + 1
        fn.replace(%(<sup>[<a id="fn-ref-#{index}" href="#fn-#{index}">#{index}</a>]</sup>))
      end

      nil
    end

  end
end
