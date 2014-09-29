require_relative 'spec_helper'

describe 'PDF Builder' do

  before(:all) do
    @book = ::Persie::Book.new(A_BOOK_PATH)
    @builder = ::Persie::PDF.new(@book, test: true)
  end

  it 'responds to #build' do
    expect(@builder.respond_to?(:build)).to be true
  end

  describe '#convert_to_html' do
    it 'generates a html file' do
      @builder.convert_to_html

      path = File.join(A_BOOK_PATH, 'tmp', 'pdf', 'a-book.html')
      expect(File.exist? path).to be true

      FileUtils.remove_dir File.join(A_BOOK_PATH, 'tmp', 'pdf')
    end
  end

  describe '#convert_to_pdf' do
    it 'generates a pdf file' do
      @builder.convert_to_html
      @builder.restart_page_number
      @builder.convert_to_pdf

      path = File.join(A_BOOK_PATH, 'builds', 'pdf', 'a-book.pdf')
      expect(File.exist? path).to be true

      FileUtils.remove_dir File.join(A_BOOK_PATH, 'tmp', 'pdf')
      FileUtils.remove_dir File.join(A_BOOK_PATH, 'builds', 'pdf')
    end
  end

end
