require 'asciidoctor'
require 'rouge'

module Persie
  # A custom Asciidoctor backend, convert AsciiDoc to O'Reilly HTMLBook.
  class HTMLBook
    include ::Asciidoctor::Converter

    register_for 'htmlbook'

    EPUB_FORMATS = ['epub', 'duokan']

    QUOTE_TAGS = {
      :emphasis    => ['<em>',     '</em>',     true],
      :strong      => ['<strong>', '</strong>', true],
      :monospaced  => ['<code>',   '</code>',   true],
      :superscript => ['<sup>',    '</sup>',    true],
      :subscript   => ['<sub>',    '</sub>',    true],
      :double      => ['&#8220;',  '&#8221;',   false],
      :single      => ['&#8216;',  '&#8217;',   false],
      :asciimath   => ['\\$',      '\\$',       false],
      :latexmath   => ['\\(',      '\\)',       false]
      # Opal can't resolve these constants when referenced here
      #:asciimath   => INLINE_MATH_DELIMITERS[:asciimath] + [false],
      #:latexmath   => INLINE_MATH_DELIMITERS[:latexmath] + [false]
    }
    QUOTE_TAGS.default = [nil, nil, nil]

    WordJoiner = [65279].pack 'U*'

    def initialize(backend, opts={})
      super

      # These two vars are used to auto-numbering figures, listing, etc
      @reset_num = nil
      @nums = {
        'image' => 0,
        'listing' => 0,
        'table' => 0
      }
    end

    def convert(node, transform = nil)
      transform ||= node.node_name
      send(transform, node)
    end

    def document(node)
      # In this method, node == node.document
      # In other methods, you should use node.document
      ebook_format = node.attr('ebook-format')
      result = []

      result << '<!DOCTYPE html>'
      lang_attr = %(lang="#{node.attr('lang', 'en')}")
      if EPUB_FORMATS.include? ebook_format
        result << %(<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:#{lang_attr} #{lang_attr})
      else
        result << %(<html xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.w3.org/1999/xhtml" #{lang_attr}>)
      end
      result << %(<head>)
      result << %(<meta http-equiv="Content-Type" content="text/html;charset=#{node.attr 'encoding', 'UTF-8'}"/>)
      result << %(<title>#{node.doctitle(:sanitize => true) || node.attr('untitled-label')}</title>)
      if ebook_format === 'site'
        result << %(<meta http-equiv="X-UA-Compatible" content="IE=edge"/>)
        result << %(<meta name="viewport" content="width=device-width, initial-scale=1.0"/>)
      end
      result << %(<meta name="generator" content="Persie #{node.attr 'persie-version'}"/>)
      result << %(<meta name="date" content="#{node.revdate}"/>)
      result << %(<meta name="application-name" content="#{node.attr 'app-name'}"/>) if node.attr? 'app-name'
      result << %(<meta name="description" content="#{node.attr 'description'}"/>) if node.attr? 'description'
      result << %(<meta name="keywords" content="#{node.attr 'keywords'}"/>) if node.attr? 'keywords'
      result << %(<meta name="author" content="#{node.attr 'authors'}"/>) if node.attr? 'authors'
      result << %(<meta name="copyright" content="#{node.attr 'copyright'}"/>) if node.attr? 'copyright'

      # FIXME: stylesheet path for site and epub
      stylesheet_path = File.join(node.attr('theme-dir'), ebook_format, 'style.css')
      result << %(<link rel="stylesheet" href="#{stylesheet_path}"/>)

      if node.attr? 'math'
        result << %(<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  tex2jax: {
    inlineMath: [#{::Asciidoctor::INLINE_MATH_DELIMITERS[:latexmath]}],
    displayMath: [#{::Asciidoctor::BLOCK_MATH_DELIMITERS[:latexmath]}],
    ignoreClass: "nomath|nolatexmath"
  },
  asciimath2jax: {
    delimiters: [#{BLOCK_MATH_DELIMITERS[:asciimath]}],
    ignoreClass: "nomath|noasciimath"
  }
});
</script>
<script type="text/javascript" src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-MML-AM_HTMLorMML"></script>
<script>document.addEventListener('DOMContentLoaded', MathJax.Hub.TypeSet)</script>)
      end

      unless (docinfo_content = node.docinfo).empty?
        result << docinfo_content
      end

      result << '</head>'

      body_attrs = []
      body_attrs << %(data-type="book")
      body_attrs << %(id="#{node.id}") if node.id
      result << %(<body #{body_attrs * ' '}>)

      cover_path = File.join(node.attr('theme-dir'), ebook_format, "#{ebook_format}.png")
      if File.exist? cover_path
        result << %(<figure data-type="cover"><img src="#{cover_path}"/></figure>)
      end

      if ebook_format == 'pdf'
        result << titlepage(node)
        result << toc(node)
      end

      result << node.content

      result << '</body>'
      result << '</html>'

      result * "\n"
    end

    # NOTE: not touched
    def embedded(node)
      result = []
      if !node.notitle && node.has_header?
        id_attr = node.id ? %( id="#{node.id}") : nil
        result << %(<h1#{id_attr}>#{node.header.title}</h1>)
      end

      result << node.content

      if node.footnotes? && !(node.attr? 'nofootnotes')
        result << %(<div id="footnotes">
<hr#{@void_element_slash}>)
        node.footnotes.each do |footnote|
          result << %(<div class="footnote" id="_footnote_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a> #{footnote.text}
</div>)
        end

        result << '</div>'
      end

      result * "\n"
    end

    def outline(node, opts = {})
      return if (sections = node.sections).empty?

      sectnumlevels = opts[:sectnumlevels] || (node.document.attr 'sectnumlevels', 3).to_i
      toclevels = opts[:toclevels] || (node.document.attr 'toclevels', 2).to_i
      result = []

      result << '<ol>'
      sections.each do |section|
        data_type_attr = %( data-type="#{data_type_of(section)}")
        section_num = (section.numbered && !section.caption && section.level <= sectnumlevels) ? %(#{section.sectnum} ) : nil
        result << %(<li#{data_type_attr}>)
        result << %(<a href="##{section.id}">#{section_num}#{section.captioned_title}</a>)
        if section.level < toclevels && (child_toc_level = outline section, :toclevels => toclevels, :secnumlevels => sectnumlevels)
          result << child_toc_level
        end
        result << '</li>'
      end
      result << '</ol>'
      result * "\n"
    end

    def toc(node)
      doc = node.document
      return nil unless doc.attr?('toc')

      result = [%(<nav data-type="toc" class="#{doc.attr 'toc-class', 'toc'}">)]
      result << %(<h1>#{doc.attr 'toc-title'}</h1>)
      result << outline(node)
      result << '</nav>'
      result * "\n"
    end

    # For ePub only
    def navigation_document(node, spine)
      doctitle_sanitized = ((node.doctitle sanitize: true) || (node.attr 'untitled-label')).gsub WordJoiner, ''
      result = ['<!DOCTYPE html>']
      result << %(<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="#{lang = (node.attr 'lang', 'en')}" lang="#{lang}">)
      result << '<head>'
      result << %(<meta http-equiv="Content-Type" content="text/html;charset=#{node.attr 'encoding', 'UTF-8'}"/>)
      result << %(<title>#{doctitle_sanitized}</title>)
      # FIXME: stylesheet path
      result << '<link rel="stylesheet" type="text/css" href="styles/epub3.css"/>'
      result << '</head>'
      result << '<body>'
      result << '<h1>#{doctitle_sanitized}</h1>'
      result << %(<nav data-type="toc" epub:type="toc" class="#{doc.attr 'toc-class', 'toc'}">)
      result << %(<h2>#{node.attr 'toc-title'}</h2>)
      result << '<ol>'
      spine.each do |item|
        result << %(<li><a href="#{item.id || (item.attr 'docname')}.xhtml">#{((item.doctitle sanitize: true) || (item.attr 'untitled-label')).gsub WordJoiner, ''}</a></li>)
      end
      result << '</ol>'
      result << '</nav>'
      result << '</body>'
      result << '</html>'
      result * "\n"
    end

    def section(node)
      ebook_format = node.document.attr('ebook-format')
      slevel = node.level
      slevel = 1 if slevel == 0 && node.special
      id_attr = node.id ? %( id="#{node.id}") : nil
      class_attr = node.role ? %( class="#{node.role}") : nil
      epub_type_attr = (EPUB_FORMATS.include?(ebook_format) && node.special) ? %( epub:type="#{node.sectname}") : nil
      sectnum = if node.numbered && !node.caption && slevel <= (node.document.attr 'sectnumlevels', 3).to_i && ![0, 1].include?(slevel)
        %(<span>#{node.sectnum}</span> )
      else
        nil
      end
      data_type = data_type_of(node)
      h_level = if slevel == 0
         1
      elsif slevel == 1
        1
      else
        slevel - 1
      end
      wrapper_tag = if data_type != 'part'
        'section'
      else
        'div'
      end

      result = [%(<#{wrapper_tag} data-type="#{data_type}"#{epub_type_attr}#{id_attr}#{class_attr}>)]
      result << %(<h#{h_level}>#{sectnum}#{node.title}</h#{h_level}>)
      result << node.content
      result << %(</#{wrapper_tag}>)

      result * "\n"
    end

    def admonition(node)
      ebook_format = node.document.attr('ebook-format')
      id_attr = node.id ? %( id="#{node.id}") : nil
      class_attr = node.role ? %( class="#{node.role}") : nil
      epub_type_attr = nil
      name = node.attr 'name'
      title_element = node.title? ? %(<h1>#{node.title}</h1>\n) : nil

      if EPUB_FORMATS.include? ebook_format
        epub_type = case type
        when 'tip'
          'help'
        when 'note'
          'note'
        when 'important', 'warning', 'caution'
          'warning'
        end
        epub_type_attr = %( eput:type=#{epub_type})
      end

      result = [%(<div data-type="#{name}"#{epub_type_attr}#{id_attr}#{class_attr}>)]
      result << title_element
      result << node.content
      result << '</div>'

      result * "\n"
    end

    # NOTE: not touched
    def audio(node)
      xml = node.document.attr? 'htmlsyntax', 'xml'
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['audioblock', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : nil
      %(<div#{id_attribute}#{class_attribute}>
#{title_element}<div class="content">
<audio src="#{node.media_uri(node.attr 'target')}"#{(node.option? 'autoplay') ? (append_boolean_attribute 'autoplay', xml) : nil}#{(node.option? 'nocontrols') ? nil : (append_boolean_attribute 'controls', xml)}#{(node.option? 'loop') ? (append_boolean_attribute 'loop', xml) : nil}>
Your browser does not support the audio tag.
</audio>
</div>
</div>)
    end

    def colist(node)
      result = []
      digits = ['&#x278a;', '&#x278b;', '&#x278c;', '&#x278d;', '&#x278e;', '&#x278f;', '&#x2790;', '&#x279a;', '&#x2792;', '&#x2793;']
      id_attr = node.id ? %( id="#{node.id}") : nil
      classes = ['calloutlist', node.style, node.role].compact
      class_attr = %( class="#{classes * ' '}")
      start_attr = node.attr?('start') ? %( start="#{node.attr('start')}") : nil

      result << %(<ol#{id_attr}#{class_attr}#{start_attr}>)

      node.items.each_with_index do |item, i|
        result << '<li>'
        result << %(<p>#{digits[i]}#{item.text}</p>)
        result << item.content if item.block?
        result << '</li>'
      end

      result << '</ol>'
      result * "\n"
    end

    def dlist(node)
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : nil

      classes = case node.style
      when 'qanda'
        ['qlist', 'qanda', node.role]
      when 'horizontal'
        ['hdlist', node.role]
      else
        ['dlist', node.style, node.role]
      end.compact

      class_attribute = %( class="#{classes * ' '}")

      result << %(<div#{id_attribute}#{class_attribute}>)
      result << %(<div class="title">#{node.title}</div>) if node.title?
      case node.style
      when 'qanda'
        result << '<ol>'
        node.items.each do |terms, dd|
          result << '<li>'
          [*terms].each do |dt|
            result << %(<p><em>#{dt.text}</em></p>)
          end
          if dd
            result << %(<p>#{dd.text}</p>) if dd.text?
            result << dd.content if dd.blocks?
          end
          result << '</li>'
        end
        result << '</ol>'
      when 'horizontal'
        result << '<table>'
        if (node.attr? 'labelwidth') || (node.attr? 'itemwidth')
          result << '<colgroup>'
          col_style_attribute = (node.attr? 'labelwidth') ? %( style="width: #{(node.attr 'labelwidth').chomp '%'}%;") : nil
          result << %(<col#{col_style_attribute}/>)
          col_style_attribute = (node.attr? 'itemwidth') ? %( style="width: #{(node.attr 'itemwidth').chomp '%'}%;") : nil
          result << %(<col#{col_style_attribute}/>)
          result << '</colgroup>'
        end
        node.items.each do |terms, dd|
          result << '<tr>'
          result << %(<td class="hdlist1#{(node.option? 'strong') ? ' strong' : nil}">)
          terms_array = [*terms]
          last_term = terms_array[-1]
          terms_array.each do |dt|
            result << dt.text
            result << '<br/>' if dt != last_term
          end
          result << '</td>'
          result << '<td class="hdlist2">'
          if dd
            result << %(<p>#{dd.text}</p>) if dd.text?
            result << dd.content if dd.blocks?
          end
          result << '</td>'
          result << '</tr>'
        end
        result << '</table>'
      else
        result << '<dl>'
        dt_style_attribute = node.style ? nil : ' class="hdlist1"'
        node.items.each do |terms, dd|
          [*terms].each do |dt|
            result << %(<dt#{dt_style_attribute}>#{dt.text}</dt>)
          end
          if dd
            result << '<dd>'
            result << %(<p>#{dd.text}</p>) if dd.text?
            result << dd.content if dd.blocks?
            result << '</dd>'
          end
        end
        result << '</dl>'
      end

      result << '</div>'
      result * "\n"
    end

    def example(node)
      id_attr = node.id ? %( id="#{node.id}") : nil
      class_attr = node.role ? %( class="#{node.role}") : nil
      title_element = node.title? ? %(<h5>#{node.captioned_title}</h5>\n) : nil

      %(<div data-type="example"#{id_attr}#{class_attr}>#{title_element}#{node.content}</div>)
    end

    # NOTE: not touched
    def floating_title(node)
      tag_name = %(h#{node.level + 1})
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = [node.style, node.role].compact
      %(<#{tag_name}#{id_attribute} class="#{classes * ' '}">#{node.title}</#{tag_name}>)
    end

    def image(node)
      align = (node.attr? 'align') ? (node.attr 'align') : nil
      float = (node.attr? 'float') ? (node.attr 'float') : nil
      style_attr = if align || float
        styles = [align ? %(text-align: #{align}) : nil, float ? %(float: #{float}) : nil].compact
        %( style="#{styles * ';'}")
      end

      width_attr = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
      height_attr = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : nil

      img_element = %(<img src="#{node.image_uri node.attr('target')}" alt="#{node.attr 'alt'}"#{width_attr}#{height_attr}/>)
      if (link = node.attr 'link')
        img_element = %(<a href="#{link}">#{img_element}</a>)
      end
      id_attr = node.id ? %( id="#{node.id}") : nil
      classes = ['image', node.style, node.role].compact
      class_attr = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<<figcaption>>#{captioned_title_mod_of(node)}</<figcaption>>) : '<figcaption/>'

      %(<figure#{id_attr}#{class_attr}#{style_attr}>#{img_element}#{title_element}</figure>)
    end

    # Use rouge to highlight source code
    # You can set `:persie-hightlight:' document attribute to trun on highlight
    # You can set `linenums' block attribute to turn on line numbers for specific source block
    def listing(node)
      if node.style == 'source'
        language = node.attr('language') # will fall back to global language attribute
        highlight = node.document.attr?('persie-highlight')
        linenums = node.attr?('linenums')

        if highlight
          classes = "highlight language-#{language}"
          pre_element = rouge_highlight(node.content, language, classes, linenums)
        else
          if linenums
            pre_element = rouge_highlight(node.content, 'plaintext', '', true)
          else
            pre_element = %(<pre><code class="language-#{language}">#{node.content}<code></pre>)
          end
        end
      else
        pre_element = %(<pre>#{node.content}</pre>)
      end

      id_attr = node.id ? %( id="#{node.id}") : nil
      class_attr = node.role ? %( class="#{node.role}") : nil
      title_element = node.title? ? %(<h5>#{captioned_title_mod_of(node)}</h5>\n) : nil

      result = [%(<div#{id_attr} data-type="listing"#{class_attr}>)]
      result << title_element
      result << pre_element
      result << '</div>'

      result * "\n"
    end

    def literal(node)
      %(<pre>#{node.content}</pre>)
    end

    def math(node)
      id_attr = node.id ? %( id="#{node.id}") : nil
      class_attr = node.role ? %( class="#{node.role}") : nil
      title_element = node.title? ? %(<h5>#{node.title}</h5>\n) : nil
      open, close = ::Asciidoctor::BLOCK_MATH_DELIMITERS[node.style.to_sym]
      # QUESTION should the content be stripped already?
      equation = node.content.strip
      if node.subs.nil_or_empty? && !(node.attr? 'subs')
        equation = node.sub_specialcharacters equation
      end

      unless (equation.start_with? open) && (equation.end_with? close)
        equation = %(#{open}#{equation}#{close})
      end

      result = [%(<div data-type="equation"#{id_attr}#{class_attr}>)]
      result << title_element
      result << %(<p data-type="tex">#{equation}</p>)
      result << '</div>'

      result * "\n"
    end

    def olist(node)
      result = []
      id_attr = node.id ? %( id="#{node.id}") : nil
      classes = [node.style, node.role].compact
      class_attr = %( class="#{classes * ' '}")
      type_attr = (keyword = node.list_marker_keyword) ? %( type="#{keyword}") : nil
      start_attr = (node.attr? 'start') ? %( start="#{node.attr 'start'}") : nil
      result << %(<ol#{id_attr}#{class_attr}#{type_attr}#{start_attr}>)

      node.items.each do |item|
        result << '<li>'
        result << %(<p>#{item.text}</p>)
        result << item.content if item.blocks?
        result << '</li>'
      end

      result << '</ol>'

      result * "\n"
    end

    # NOTE: not touched
    def open(node)
      if (style = node.style) == 'abstract'
        if node.parent == node.document && node.document.doctype == 'book'
          warn 'asciidoctor: WARNING: abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
          ''
        else
          id_attr = node.id ? %( id="#{node.id}") : nil
          title_el = node.title? ? %(<div class="title">#{node.title}</div>) : nil
          %(<div#{id_attr} class="quoteblock abstract#{(role = node.role) && " #{role}"}">
#{title_el}<blockquote>
#{node.content}
</blockquote>
</div>)
        end
      elsif style == 'partintro' && (node.level != 0 || node.parent.context != :section || node.document.doctype != 'book')
        warn 'asciidoctor: ERROR: partintro block can only be used when doctype is book and it\'s a child of a book part. Excluding block content.'
        ''
      else
          id_attr = node.id ? %( id="#{node.id}") : nil
          title_el = node.title? ? %(<div class="title">#{node.title}</div>) : nil
        %(<div#{id_attr} class="openblock#{style && style != 'open' ? " #{style}" : ''}#{(role = node.role) && " #{role}"}">
#{title_el}<div class="content">
#{node.content}
</div>
</div>)
      end
    end

    def page_break(node)
      ebook_format = node.document.attr('ebook-format')
      if EPUB_FORMATS.include? ebook_format
        '<hr epub:type="pagebreak"/>'
      else
        '<div style="page-break-after:always;"></div>'
      end
    end

    def paragraph(node)
      id_attr = node.id ? %( id="#{node.id}") : nil
      class_attr = node.role ? %( class="#{node.role}") : nil

      %(<p#{id_attr}#{class_attr}>#{node.content}</p>)
    end

    def preamble(node)
      %(<section data-type="preamble">#{node.content}</section>)
    end

    def quote(node)
      id_attr = node.id ? %( id="#{node.id}") : nil
      class_attr = node.role ? %( class="#{node.role}") : nil
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil

      if attribution || citetitle
        cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : nil
        attribution_text = attribution ? %(#{citetitle ? "<br/>\n" : nil}&#8212; #{attribution}) : nil
        attribution_element = %(\n<p class="attribution">\n#{cite_element}#{attribution_text}\n</p>)
      else
        attribution_element = nil
      end

      %(<blockquote#{id_attr}#{class_attr}>#{node.content}#{attribution_element}</blockquote>)
    end

    def thematic_break(node)
      '<hr/>'
    end

    def sidebar(node)
      ebook_format = node.document.attr('ebook-format')
      id_attr = node.id ? %( id="#{node.id}") : nil
      role = node.role ? %( #{node.role}) : nil
      class_attr = %( class="sidebar#{role}")
      title_element = node.title? ? %(<h5>#{node.title}</h5>) : nil
      epub_type_attr = if EPUB_FORMATS.include?(ebook_format)
        ' epub:type="sidebar"'
      else
        nil
      end

      result = [%(<aside data-type="sidebar"#{epub_type_attr}#{id_attr}#{class_attr}>)]
      result << title_element
      result << node.content
      result << '</aside>'

      result * "\n"
    end

    def table(node)
      result = []
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['tableblock', %(frame-#{node.attr 'frame', 'all'}), %(grid-#{node.attr 'grid', 'all'})]
      if (role_class = node.role)
        classes << role_class
      end
      class_attribute = %( class="#{classes * ' '}")
      styles = [(node.option? 'autowidth') ? nil : %(width: #{node.attr 'tablepcwidth'}%;), (node.attr? 'float') ? %(float: #{node.attr 'float'};) : nil].compact
      style_attribute = styles.size > 0 ? %( style="#{styles * ' '}") : nil

      result << %(<table#{id_attribute}#{class_attribute}#{style_attribute}>)
      result << %(<caption class="title">#{captioned_title_mod_of(node)}</caption>) if node.title?
      if (node.attr 'rowcount') > 0
        slash = '/'
        result << '<colgroup>'
        if node.option? 'autowidth'
          tag = %(<col#{slash}>)
          node.columns.size.times do
            result << tag
          end
        else
          node.columns.each do |col|
            result << %(<col style="width: #{col.attr 'colpcwidth'}%;"#{slash}>)
          end
        end
        result << '</colgroup>'
        [:head, :foot, :body].select {|tsec| !node.rows[tsec].empty? }.each do |tsec|
          result << %(<t#{tsec}>)
          node.rows[tsec].each do |row|
            result << '<tr>'
            row.each do |cell|
              if tsec == :head
                cell_content = cell.text
              else
                case cell.style
                when :asciidoc
                  cell_content = %(<div>#{cell.content}</div>)
                when :verse
                  cell_content = %(<div class="verse">#{cell.text}</div>)
                when :literal
                  cell_content = %(<div class="literal"><pre>#{cell.text}</pre></div>)
                else
                  cell_content = ''
                  cell.content.each do |text|
                    cell_content = %(#{cell_content}<p class="tableblock">#{text}</p>)
                  end
                end
              end

              cell_tag_name = (tsec == :head || cell.style == :header ? 'th' : 'td')
              cell_class_attribute = %( class="tableblock halign-#{cell.attr 'halign'} valign-#{cell.attr 'valign'}")
              cell_colspan_attribute = cell.colspan ? %( colspan="#{cell.colspan}") : nil
              cell_rowspan_attribute = cell.rowspan ? %( rowspan="#{cell.rowspan}") : nil
              cell_style_attribute = (node.document.attr? 'cellbgcolor') ? %( style="background-color: #{node.document.attr 'cellbgcolor'};") : nil
              result << %(<#{cell_tag_name}#{cell_class_attribute}#{cell_colspan_attribute}#{cell_rowspan_attribute}#{cell_style_attribute}>#{cell_content}</#{cell_tag_name}>)
            end
            result << '</tr>'
          end
          result << %(</t#{tsec}>)
        end
      end
      result << '</table>'
      result * "\n"
    end

    def ulist(node)
      result = []
      id_attr = node.id ? %( id="#{node.id}") : nil
      classes = [node.style, node.role].compact
      marker_checked = nil
      marker_unchecked = nil
      if (checklist = node.option? 'checklist')
        classes.insert 0, 'checklist'
        if node.option? 'interactive'
          if node.document.attr? 'htmlsyntax', 'xml'
            marker_checked = '<input type="checkbox" data-item-complete="1" checked="checked"/> '
            marker_unchecked = '<input type="checkbox" data-item-complete="0"/> '
          else
            marker_checked = '<input type="checkbox" data-item-complete="1" checked> '
            marker_unchecked = '<input type="checkbox" data-item-complete="0"> '
          end
        else
          if node.document.attr? 'icons', 'font'
            marker_checked = '<i class="icon-check"></i> '
            marker_unchecked = '<i class="icon-check-empty"></i> '
          else
            marker_checked = '&#10003; '
            marker_unchecked = '&#10063; '
          end
        end
      end
      result << %(<ul#{id_attr} class="#{classes * ' '}">)

      node.items.each do |item|
        result << '<li>'
        if checklist && (item.attr? 'checkbox')
          result << %(<p>#{(item.attr? 'checked') ? marker_checked : marker_unchecked}#{item.text}</p>)
        else
          result << %(<p>#{item.text}</p>)
        end
        result << item.content if item.blocks?
        result << '</li>'
      end

      result << '</ul>'
      result * "\n"
    end

    def verse(node)
      id_attr = node.id ? %( id="#{node.id}") : nil
      classes = ['verse', node.role].compact
      class_attr = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : nil
      attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
      citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil
      if attribution || citetitle
        cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : nil
        attribution_text = attribution ? %(#{citetitle ? "<br/>\n" : nil}&#8212; #{attribution}) : nil
        attribution_element = %(\n<p data-type="attribution">\n#{cite_element}#{attribution_text}\n</p>)
      else
        attribution_element = nil
      end

      result = [%(<blockquote data-type="epigraph"#{id_attr}#{class_attr}>)]
      result << %(<pre>#{node.content.chomp}</pre>)
      result << attribution_element
      result << '</blockquote>'
      result * "\n"
    end

    # NOTE: not touched
    def video(node)
      xml = node.document.attr? 'htmlsyntax', 'xml'
      id_attribute = node.id ? %( id="#{node.id}") : nil
      classes = ['videoblock', node.style, node.role].compact
      class_attribute = %( class="#{classes * ' '}")
      title_element = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : nil
      width_attribute = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
      height_attribute = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : nil
      case node.attr 'poster'
      when 'vimeo'
        start_anchor = (node.attr? 'start') ? "#at=#{node.attr 'start'}" : nil
        delimiter = '?'
        autoplay_param = (node.option? 'autoplay') ? "#{delimiter}autoplay=1" : nil
        delimiter = '&amp;' if autoplay_param
        loop_param = (node.option? 'loop') ? "#{delimiter}loop=1" : nil
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="//player.vimeo.com/video/#{node.attr 'target'}#{start_anchor}#{autoplay_param}#{loop_param}" frameborder="0"#{append_boolean_attribute 'webkitAllowFullScreen', xml}#{append_boolean_attribute 'mozallowfullscreen', xml}#{append_boolean_attribute 'allowFullScreen', xml}></iframe>
</div>
</div>)
      when 'youtube'
        start_param = (node.attr? 'start') ? "&amp;start=#{node.attr 'start'}" : nil
        end_param = (node.attr? 'end') ? "&amp;end=#{node.attr 'end'}" : nil
        autoplay_param = (node.option? 'autoplay') ? '&amp;autoplay=1' : nil
        loop_param = (node.option? 'loop') ? '&amp;loop=1' : nil
        controls_param = (node.option? 'nocontrols') ? '&amp;controls=0' : nil
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<iframe#{width_attribute}#{height_attribute} src="//www.youtube.com/embed/#{node.attr 'target'}?rel=0#{start_param}#{end_param}#{autoplay_param}#{loop_param}#{controls_param}" frameborder="0"#{(node.option? 'nofullscreen') ? nil : (append_boolean_attribute 'allowfullscreen', xml)}></iframe>
</div>
</div>)
      else
        poster_attribute = %(#{poster = node.attr 'poster'}).empty? ? nil : %( poster="#{node.media_uri poster}")
        time_anchor = ((node.attr? 'start') || (node.attr? 'end')) ? %(#t=#{node.attr 'start'}#{(node.attr? 'end') ? ',' : nil}#{node.attr 'end'}) : nil
        %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<video src="#{node.media_uri(node.attr 'target')}#{time_anchor}"#{width_attribute}#{height_attribute}#{poster_attribute}#{(node.option? 'autoplay') ? (append_boolean_attribute 'autoplay', xml) : nil}#{(node.option? 'nocontrols') ? nil : (append_boolean_attribute 'controls', xml)}#{(node.option? 'loop') ? (append_boolean_attribute 'loop', xml) : nil}>
Your browser does not support the video tag.
</video>
</div>
</div>)
      end
    end

    def inline_anchor(node)
      target = node.target
      case node.type
      when :xref
        refid = (node.attr 'refid') || target
        # FIXME seems like text should be prepared already
        text = node.text || (node.document.references[:ids][refid] || %([#{refid}]))
        %(<a href="#{target}">#{text}</a>)
      when :ref
        %(<a id="#{target}"></a>)
      when :link
        class_attr = (role = node.role) ? %( class="#{role}") : nil
        id_attr = (node.attr? 'id') ? %( id="#{node.attr 'id'}") : nil
        window_attr = (node.attr? 'window') ? %( target="#{node.attr 'window'}") : nil
        %(<a href="#{target}"#{id_attr}#{class_attr}#{window_attr}>#{node.text}</a>)
      when :bibref
        %(<a id="#{target}"></a>[#{target}])
      else
        warn %(asciidoctor: WARNING: unknown anchor type: #{node.type.inspect})
      end
    end

    def inline_break(node)
      %(#{node.text}<br/>)
    end

    def inline_button(node)
      %(<b class="button">#{node.text}</b>)
    end

    def inline_callout(node)
      if node.document.attr? 'icons', 'font'
        %(<i class="conum" data-value="#{node.text}"></i><b>(#{node.text})</b>)
      elsif node.document.attr? 'icons'
        src = node.icon_uri("callouts/#{node.text}")
        %(<img src="#{src}" alt="#{node.text}"/>)
      else
        %(<b class="conum">(#{node.text})</b>)
      end
    end

    def inline_footnote(node)
      if (index = node.attr 'index')
        if node.type == :xref
          %(<a data-type="footnoteref" href="##{node.target}">#{index}</a>)
        else
          id_attr = node.id ? %( id="#{node.id}") : nil
          %(<span data-type="footnote"#{id_attr}>#{node.text}</span>)
        end
      elsif node.type == :xref
        %(<span data-type="footnoteref red">#{node.text}</span>)
      end
    end

    def inline_image(node)
      if (type = node.type) == 'icon' && (node.document.attr? 'icons', 'font')
        style_class = "icon-#{node.target}"
        if node.attr? 'size'
          style_class = %(#{style_class} icon-#{node.attr 'size'})
        end
        if node.attr? 'rotate'
          style_class = %(#{style_class} icon-rotate-#{node.attr 'rotate'})
        end
        if node.attr? 'flip'
          style_class = %(#{style_class} icon-flip-#{node.attr 'flip'})
        end
        title_attribute = (node.attr? 'title') ? %( title="#{node.attr 'title'}") : nil
        img = %(<i class="#{style_class}"#{title_attribute}></i>)
      elsif type == 'icon' && !(node.document.attr? 'icons')
        img = %([#{node.attr 'alt'}])
      else
        resolved_target = (type == 'icon') ? (node.icon_uri node.target) : (node.image_uri node.target)

        attrs = ['alt', 'width', 'height', 'title'].map {|name|
          (node.attr? name) ? %( #{name}="#{node.attr name}") : nil
        }.join

        img = %(<img src="#{resolved_target}"#{attrs}/>)
      end

      if node.attr? 'link'
        window_attr = (node.attr? 'window') ? %( target="#{node.attr 'window'}") : nil
        img = %(<a class="image" href="#{node.attr 'link'}"#{window_attr}>#{img}</a>)
      end

      style_classes = (role = node.role) ? %(image #{type} #{role}) : type
      style_attr = (node.attr? 'float') ? %( style="float: #{node.attr 'float'}") : nil

      %(<span class="#{style_classes}"#{style_attr}>#{img}</span>)
    end

    # FIXME: need expanded asccording to asccidoctor_html
    def inline_indexterm(node)
      node.type == :visible ? node.text : ''
    end

    def inline_kbd(node)
      if (keys = node.attr 'keys').size == 1
        %(<kbd>#{keys[0]}</kbd>)
      else
        key_combo = keys.map {|key| %(<kbd>#{key}</kbd>+) }.join.chop
        %(<span class="keyseq">#{key_combo}</span>)
      end
    end

    def inline_menu(node)
      menu = node.attr 'menu'
      if !(submenus = node.attr 'submenus').empty?
        submenu_path = submenus.map {|submenu| %(<span class="submenu">#{submenu}</span>&#160;&#9656; ) }.join.chop
        %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; #{submenu_path} <span class="menuitem">#{node.attr 'menuitem'}</span></span>)
      elsif (menuitem = node.attr 'menuitem')
        %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; <span class="menuitem">#{menuitem}</span></span>)
      else
        %(<span class="menu">#{menu}</span>)
      end
    end

    def inline_quoted(node)
      open, close, is_tag = QUOTE_TAGS[node.type]
      quoted_text = if (role = node.role)
        is_tag ? %(#{open.chop} class="#{role}">#{node.text}#{close}) : %(<span class="#{role}">#{open}#{node.text}#{close}</span>)
      else
        %(#{open}#{node.text}#{close})
      end

      node.id ? %(<a id="#{node.id}"></a>#{quoted_text}) : quoted_text
    end

    private

    # Generate a title page for PDF format
    def titlepage(node)
      result = [%(<section data-type="titlepage">)]
      result << %(<h1>#{node.header.title}</h1>)
      result << %(<h2>#{node.attr :subtitle}</h2>) if node.attr? :subtitle
      if [node.attr?(:author), node.attr?('persie-translator')].any?
        result << '<p class="author">'

        if node.attr?(:author)
          author_text = if node.attr?('persie-author-label')
            node.attr('persie-author-label')
          else
            node.attr :author
          end
          result << %(<span data-type="author">#{author_text}</span>)
        end

        if node.attr?('persie-translator')
          translator_text = if node.attr?('persie-translator-label')
            node.attr('persie-translator-label')
          else
            node.attr('persie-translator')
          end
          result << %(<br/><span data-type="translator">#{translator_text}</span>)
        end

        result << '</p>'
      end

      if node.attr? 'revnumber'
        result << %(<span data-type="revnumber">#{((node.attr 'version-label') || '').downcase} #{node.attr 'revnumber'}#{(node.attr? 'revdate') ? ',' : ''}</span>)
      end
      if node.attr? 'revdate'
        result << %(<span data-type="revdate">#{node.attr 'revdate'}</span>)
      end
      if node.attr? 'revremark'
        result << %(<br/><span data-type="revremark">#{node.attr 'revremark'}</span>)
      end
      result << %(</section>)
      result * "\n"
    end

    def append_boolean_attribute(name, xml)
      xml ? %( #{name}="#{name}") : %( #{name})
    end

    # Find out the data type of a node
    def data_type_of(node)
      slevel = node.level
      data_type = if slevel == 0
        if node.title == node.document.attr('colophon-title', 'Colophon')
          'colophon'
        elsif node.title == node.document.attr('index-title', 'Index')
          'index'
        else
          'part'
        end
      elsif slevel == 1
        if node.sectname == 'preface' && node.title == node.document.attr('foreword-title', 'Foreword')
          'foreword'
        elsif node.sectname == 'preface'
          'preface'
        elsif node.sectname == 'appendix'
          'appendix'
        elsif node.title == node.document.attr('glossary-title', 'Glossary')
          'glossary'
        elsif node.title == node.document.attr('dedication-title', 'Dedication')
          'dedication'
        else
          'chapter'
        end
      else
        "sect#{slevel - 1}"
      end
    end

    # Add auto-numbered lable to images, tables and listings
    def captioned_title_mod_of(node, sep='-', after='. ')
      unless (caption = node.document.attr("#{node.context}-caption"))
        return node.captioned_title
      end

      ctx = node.context

      level_1_num = node.parent.sectnum.split('.', 2).first
      @reset_num ||= level_1_num
      if @reset_num != level_1_num
        @nums = {
          'image' => 0,
          'listing' => 0,
          'table' => 0
        }
        @nums["#{ctx}"] += 1
        @reset_num = nil
      else
        @nums["#{ctx}"] += 1
      end
      "#{caption}#{level_1_num}#{sep}#{@nums["#{ctx}"]}#{after}#{node.title}"
    end

    # Use rouge to highlight source code
    def rouge_highlight(text, lexer, classes, linenums, &b)
      lexer = ::Rouge::Lexer.find(lexer) unless lexer.respond_to? :lex
      lexer = ::Rouge::Lexers::PlainText unless lexer

      formatter = ::Rouge::Formatters::HTML.new(css_class: classes, line_numbers: linenums)

      formatter.format(lexer.lex(text), &b)
    end

  end
end
