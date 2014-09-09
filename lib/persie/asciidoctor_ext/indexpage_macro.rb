require 'asciidoctor'
require 'asciidoctor/extensions'

module Persie
  class GistMacro < Asciidoctor::Extensions::BlockMacroProcessor
    def process parent, target, attributes
      title = (attributes.has_key? 'title') ?
          %(\n<div class="title">#{attributes['title']}</div>) : nil
      source = %(<div class="gistblock">#{title}
  <div class="content">
  <script src="https://gist.github.com/#{target}.js"></script>
  </div>
  </div>)
      Asciidoctor::Block.new parent, :pass, :content_model => :raw, :source => source
    end
  end
end
