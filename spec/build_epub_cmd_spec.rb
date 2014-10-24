require_relative 'spec_helper'

describe 'Cli#build(epub)' do

  it 'generates a epub file' do
    FileUtils.cd(A_BOOK_PATH) do
      persie_command 'build epub'
      path = 'builds/epub/a-book-0.0.1.epub'

      expect(path).to be_exists

      FileUtils.remove_dir('tmp/epub')
      FileUtils.remove_dir('builds/epub')
    end
  end

  it 'generates a sample pdf file when setting -s flag' do
    FileUtils.cd(A_BOOK_PATH) do
      persie_command 'build epub -s'
      path = 'builds/epub/a-book-sample.epub'

      expect(path).to be_exists

      FileUtils.remove_dir('tmp/epub')
      FileUtils.remove_dir('builds/epub')
    end
  end

  describe 'in tmp/epub directory' do

    before(:all) do
      @pwd = Dir.pwd
      FileUtils.cd(A_BOOK_PATH)
      persie_command 'build epub'
      FileUtils.cd('tmp/epub')
    end

    after(:all) do
      FileUtils.cd A_BOOK_PATH
      FileUtils.remove_dir 'tmp/epub'
      FileUtils.remove_dir 'builds/epub'
      FileUtils.cd @pwd
    end

    it 'has a a-book.html' do
      expect('a-book.html').to be_exists
    end

    it 'has a preface.xhtml' do
      expect('preface.xhtml').to be_exists
    end

    it 'has a chapter1.xhtml' do
      expect('chapter1.xhtml').to be_exists
    end

    it 'has a chapter2.xhtml' do
      expect('chapter2.xhtml').to be_exists
    end

    it 'has a nav.xhtml' do
      expect('nav.xhtml').to be_exists
    end

    it 'has a titlepage.xhtml' do
      expect('titlepage.xhtml').to be_exists
    end

  end
end
