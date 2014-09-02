require 'asciidoctor'
require_relative 'packager'
require_relative 'spine_item_processor'

module Persie
  class Converter
    include ::Asciidoctor::Converter
    include ::Asciidoctor::Writer

    register_for 'epub'

    def initialize backend, opts
      super
      basebackend 'html'
      outfilesuffix '.epub' # dummy outfilesuffix since it may be .mobi
      htmlsyntax 'xml'
      @validate = false
      @extract = false
    end

    def convert spine_doc, name = nil
      @validate = true if spine_doc.attr? 'ebook-validate'
      @extract = true if spine_doc.attr? 'ebook-extract'
      Packager.new spine_doc, (spine_doc.attributes['spine_items'] || [spine_doc]), spine_doc.attributes['ebook-format']
    end

    # FIXME we have to package in write because we don't have access to target before this point
    def write packager, target
      # NOTE we use dirname of target since filename is calculated automatically
      packager.package validate: @validate, extract: @extract, to_dir: (::File.dirname target)
      nil
    end
  end
end
