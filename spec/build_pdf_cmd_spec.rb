require_relative 'spec_helper'

describe 'Cli#build(pdf)' do

  it 'generates a pdf file' do
    FileUtils.cd(A_BOOK_PATH) do
      persie_command 'build pdf'
      path = 'builds/pdf/a-book-0.0.1.pdf'

      expect(path).to be_exists

      FileUtils.remove_dir('tmp/pdf')
      FileUtils.remove_dir('builds/pdf')
    end
  end

  it 'generates a sample pdf file when setting -s flag' do
    FileUtils.cd(A_BOOK_PATH) do
      persie_command 'build pdf -s'
      path = 'builds/pdf/a-book-sample.pdf'

      expect(path).to be_exists

      FileUtils.remove_dir('tmp/pdf')
      FileUtils.remove_dir('builds/pdf')
    end
  end

end
