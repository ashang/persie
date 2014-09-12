require 'asciidoctor'

require 'fileutils'

require_relative 'ui'
require_relative 'asciidoctor_ext/htmlbook'
require_relative 'dependency'
require_relative 'asciidoctor_ext/sample'

module Persie
  class Builder

    END_LINE = '=' * 72

    # Gets the AsciiDoctor::Document object.
    attr_reader :document

    def initialize(book, options = {})
      @book = book
      @options = options
      @document = ::Asciidoctor.load_file(@book.master_file, adoc_options)
    end

    # Should implement in subclass.
    def build
      raise ::NotImplementedError
    end

    private

    def sample?
      return true if @options.has_key? 'sample'
      false
    end

    def check_sample
      if sample?
        if @document.sample_sections.size == 0
          UI.error 'Not setting sample, terminated!'
          UI.info END_LINE
          exit
        end
        UI.warning 'Sample only', true
      end
    end

    def register_spine_item_processor
      require_relative 'asciidoctor_ext/spine_item_processor'

      sample = sample?
      ::Asciidoctor::Extensions.register do
        include_processor SpineItemProcessor.new(@document, sample)
      end
    end


    # Options passed into AsciiDoctor loader.
    def adoc_options
      {
        safe: 1,
        backend: 'htmlbook',
        doctype: 'book',
        header_footer: true,
        attributes: adoc_attributes
      }.merge(adoc_custom_options)
    end

    # Custom Asciidoctor options in subclass.
    def adoc_custom_options
      {}
    end

    # Attributes as in AsciiDoctor loader option.
    def adoc_attributes
      attrs = {
        'persie-version' => VERSION,
        'builds-dir' => @book.builds_dir,
        'themes-dir' => @book.themes_dir,
        'imagesdir' => @book.images_dir
      }

      attrs['is-sample'] = true if sample?

      attrs.merge(adoc_custom_attributes)
    end

    # Custom Asciidoctor attributes in subclass.
    def adoc_custom_attributes
      {}
    end

    # Create directory if not exists
    def prepare_directory(path)
      dir = File.dirname(path)
      unless File.exist? dir
        FileUtils.mkdir_p dir
      end
    end

  end
end
