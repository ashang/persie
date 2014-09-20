require 'gepub'
require 'nokogiri'
require 'asciidoctor'

require_relative 'builders/pdf'
require_relative 'builders/epub'
require_relative 'builders/mobi'
require_relative 'builders/site'

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

    # Gets book's slug.
    attr_reader :slug

    def initialize(dir)
      @base_dir    = File.expand_path(dir)
      @slug        = File.basename(@base_dir)
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

    def build_site(options = {})
      Site.new(self, options).build
    end

  end
end
