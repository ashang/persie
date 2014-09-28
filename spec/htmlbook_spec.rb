require_relative 'spec_helper'

describe 'Generated contents' do

  context 'xref' do

    it 'has no prefix when ref another file in pdf' do
      str = render_string '<<file#id,text>>',
                          :attributes => {
                            'ebook-format' => 'pdf',
                            'outfilesuffix' => '.html'
                          }
      html = '<a href="#id">text</a>'
      expect(str).to eq(html)
    end

    it 'has prefix when ref another file in epub' do
      str = render_string '<<file#id,text>>',
                          :attributes => {
                            'ebook-format' => 'epub',
                            'outfilesuffix' => '.xhtml'
                          }
      html = '<a href="file.xhtml#id">text</a>'
      expect(str).to eq(html)
    end

  end

end
