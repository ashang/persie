require 'asciidoctor/extensions'

module Persie
  class SpineItemProcessor < ::Asciidoctor::Extensions::IncludeProcessor
    def initialize(document, sample = false)
      @document = document
      @sample = sample
    end

    def process(doc, reader, target, attributes)
      include_file = doc.normalize_system_path(target, reader.dir, nil, target_name: 'include file')
      unless ::File.exist? include_file
        warn %(asciidoctor: WARNING: #{reader.line_info}: include file not found: #{include_file})
        return
      end

      doc.references['spine_items'] ||= []
      basename = File.basename(include_file).split('.')[0..-2].join('.')

      if @sample
        meta = ::Asciidoctor.load_file include_file,
          safe: doc.safe,
          doctype: :article,
          parse_header_only: true

        sample_attr = meta.attributes['sample']
        doc.references['spine_items'] << basename unless sample_attr.nil?
      else
        doc.references['spine_items'] << basename
      end
    end

    def handles? target
      (@document.attr('ebook-format') == 'epub') && (::Asciidoctor::ASCIIDOC_EXTENSIONS.include? ::File.extname(target))
    end

    def update_config config
      (@config ||= {}).update config
    end
  end
end


