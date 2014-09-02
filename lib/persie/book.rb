require 'nokogiri'
require 'asciidoctor'
require 'fileutils'
require_relative 'dependency'

module Persie
  class Book
    def initialize(dir)
      @book_dir  = File.expand_path(dir)
      @tmp_dir   = File.join(@book_dir, 'tmp')
      @build_dir = File.join(@book_dir, 'build')
      @theme_dir = File.join(@book_dir, 'theme')
      @master_file = File.join(@book_dir, 'book.adoc')
      @ui = ::Persie::UI.new
    end

    def build_pdf(options={})
      @ui.info '=== Build PDF ' << '=' * 58

      unless ::Persie::Dependency.prince_installed?
        @ui.error 'Error: PrinceXML not installed'
        @ui.info '=' * 72
        exit
      end

      exit_unless_master_file_exists

      prepare_build_dir_for 'pdf'
      prepare_tmp_dir_for 'pdf'

      pdf_dir   = File.join(@build_dir, 'pdf')
      tmp_dir   = File.join(@tmp_dir, 'pdf')
      slug      = File.basename(@book_dir)
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

      cmd = `prince #{html_file} -o #{pdf_file}`
      if cmd === ''
        @ui.confirm 'PDF file created'
        @ui.info "Location: #{pdf_file}"
      else
        @ui.error 'Error: Cannot create PDF with PrinceXML'
      end
      @ui.info '=' * 72

      unless options.debug?
        FileUtils.rm_f(html_file)
      end

      nil
    end

    def build_epub(options={})

      @ui.info '=== Build ePub ' << '=' * 57

      exit_unless_master_file_exists

      prepare_build_dir_for 'epub'
      prepare_tmp_dir_for 'epub'

      epub_dir  = File.join(@build_dir, 'epub')
      tmp_dir   = File.join(@tmp_dir, 'epub')
      slug      = File.basename(@book_dir)
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

      # 2. Get spine items
      # Cannot use doc.references[:includes] directly,
      # 'cause it's a Set, no certain ordering.
      # But orders matter in spine, so we use an Asciidoctor extension.
      spine_items = ['preamble', 'toc', 'titlepage'] # these are not using `include' directive
      require_relative 'epub/spine_item_processor'
      doc = ::Asciidoctor.load_file(@master_file, adoc_options)
      spine_items.concat doc.references['spine_items']

      # 3. Split the single file into chunked files
      book_content = File.read(File.join tmp_dir, xhtml_file)
      book = ::Nokogiri::HTML(book_content)
      top_level_sections = book.xpath('//body/*')

      # stupid check, incase something goes wrong
      unless top_level_sections.count == spine_items.count
        @ui.error 'Count of sections DO NOT equal to spine items count.'
        exit
      end

      sep = '<body data-type="book">'
      tpl_before = book_content.split(sep).first
      tpl_after  = %(</body>\n</html>)

      top_level_sections.each_with_index do |node, i|
        path = File.join(tmp_dir, "#{spine_items[i]}.xhtml")
        File.open(path, 'w') do |f|
          f.puts tpl_before
          f.puts sep
          f.puts node.to_xhtml
          f.puts tpl_after
        end
      end

      # TODO
      # footnotes and xrefs

      nil
    end

    private

    def exit_unless_master_file_exists
      unless File.exist? @master_file
        @ui.error "Error: #{@master_file} not exists"
        @ui.info '=' * 72
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
      {
        'persie-version' => ::Persie::VERSION,
        'build-dir' => @build_dir,
        'theme-dir' => @theme_dir,
        'ebook-format' => format
      }
    end

  end
end
