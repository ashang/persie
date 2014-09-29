require_relative 'spec_helper'

describe 'Cli#build(pdf)' do

  it 'generates a pdf file' do
    FileUtils.cd(A_BOOK_PATH) do
      persie_command 'build pdf'
      path = 'builds/pdf/a-book.pdf'
      expect(File.exist?(path)).to be true
      FileUtils.remove_dir('tmp/pdf')
      FileUtils.remove_dir('builds/pdf')
    end
  end

  it 'generates a sample pdf file' do
    FileUtils.cd(A_BOOK_PATH) do
      persie_command 'build pdf -s'
      path = 'builds/pdf/a-book-sample.pdf'
      expect(File.exist?(path)).to be true
      FileUtils.remove_dir('tmp/pdf')
      FileUtils.remove_dir('builds/pdf')
    end
  end

end
