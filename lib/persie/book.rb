require 'asciidoctor'
require 'fileutils'
require_relative 'dependency'

module Persie
  class Book
    def initialize(dir)
      @book_dir  = File.expand_path(dir)
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

      pdf_dir   = File.join(@build_dir, 'pdf')
      slug      = File.basename(@book_dir)
      html_file = File.join(pdf_dir, "#{slug}.html")
      pdf_file  = File.join(pdf_dir, "#{slug}.pdf")

      adoc_options = {
        :safe => 1,
        :backend => 'htmlbook',
        :doctype => 'book',
        :to_dir => pdf_dir,
        :to_file => "#{slug}.html",
        :attributes => custom_attributes_for('pdf')
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
      require_relative 'epub/packager' unless defined? ::Persie::Packager
      require_relative 'epub/spine_item_processor' unless defined? ::Persie::SpineItemProcessor

      @ui.info '=== Build ePub ' << '=' * 57

      exit_unless_master_file_exists

      epub_dir = File.join(@build_dir, 'epub')

      adoc_options = {
        safe: 1,
        backend: 'htmlbook',
        doctype: 'book',
        attributes: custom_attributes_for('epub')
      }
      ::Asciidoctor::Extensions.register do |document|
        include_processor ::Persie::SpineItemProcessor
      end
      spine_doc = ::Asciidoctor.load_file(@master_file, adoc_options)

      packager = ::Persie::Packager.new(spine_doc,
                                        (spine_doc.references[:spine_items] || [spine_doc]),
                                        epub_dir,
                                        :epub)
      packager.package validate: validate, extract: extract

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
