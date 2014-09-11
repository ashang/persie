require 'asciidoctor/extensions'

module Persie
  class SpineItemProcessor < ::Asciidoctor::Extensions::IncludeProcessor
    def initialize(document)
      @document = document
    end

    # NOTE only fires for includes in spine document if registered directly on the instance of the spine document
    def process(doc, reader, target, attributes)
      spine_doc = doc
      unless ::File.exist?(include_file = (spine_doc.normalize_system_path target, reader.dir, nil, target_name: 'include file'))
        warn %(asciidoctor: WARNING: #{reader.line_info}: include file not found: #{include_file})
        return
      end

      basename = File.basename(include_file).split('.')[0..-2].join('.')

      (spine_doc.references['spine_items'] ||= []) << basename
      # NOTE if there are attribute assignments between the include directives,
      # then this ordered list is not continguous, so bailing on the idea
      #reader.replace_line %(. link:#{::File.basename(spine_item_doc.attr 'outfile')}[#{spine_item_doc.doctitle}])
    end

    # handles? should get the attributes on include directive as the second argument
    def handles? target
      (@document.attr('ebook-format') == 'epub') && (::Asciidoctor::ASCIIDOC_EXTENSIONS.include? ::File.extname(target))
    end

    # FIXME this method shouldn't be required
    def update_config config
      (@config ||= {}).update config
    end
  end

  ::Asciidoctor::Extensions.register do
    include_processor SpineItemProcessor.new(@document)
  end
end


