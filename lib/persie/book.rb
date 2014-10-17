require 'gepub'
require 'nokogiri'
require 'asciidoctor'

require_relative 'builders/pdf'
require_relative 'builders/epub'
require_relative 'builders/mobi'
require_relative 'builders/single_html'
require_relative 'builders/multiple_htmls'


module Persie
  class Book

    # Gets base directory.
    attr_reader :base_dir

    # Gets builds directory path.
    attr_reader :builds_dir

    # Gets themes directory path.
    attr_reader :themes_dir

    # Gets images directory path.
    attr_reader :images_dir

    # Gets tmp directory path.
    attr_reader :tmp_dir

    # Gets master file path.
    attr_reader :master_file

    # Gets/Sets book slug.
    attr_accessor :slug

    def initialize(dir)
      @base_dir    = File.expand_path(dir)
      @tmp_dir     = File.join(@base_dir, 'tmp')
      @builds_dir  = File.join(@base_dir, 'builds')
      @themes_dir  = File.join(@base_dir, 'themes')
      @images_dir  = File.join(@base_dir, 'images')
      @master_file = File.join(@base_dir, 'book.adoc')
    end

    def build_pdf(options = {})
      PDF.new(self, options).build
    end

    def build_epub(options = {})
      Epub.new(self, options).build
    end

    def build_mobi(options = {})
      Mobi.new(self, options).build
    end

    def build_single_html(options = {})
      SingleHTML.new(self, options).build
    end

    def build_multiple_htmls(options = {})
      MultipleHTMLs.new(self, options).build
    end

  end
end
