require_relative 'spec_helper'

describe 'Cli#new' do

  before(:all) do
    @book_slug = 'sample-book'
    @tmp_dir = File.join(::Persie::GEM_ROOT, 'tmp')
    @book_dir = File.join(@tmp_dir, @book_slug)
    @pwd = Dir.pwd

    FileUtils.mkdir_p(@tmp_dir) unless Dir.exist? @tmp_dir

    FileUtils.cd(@tmp_dir) do
      persie_command "new #{@book_slug}"
    end

    FileUtils.cd @book_dir
  end

  after(:all) do
    FileUtils.remove_dir(@book_dir)
    FileUtils.cd @pwd
  end

  it 'generates a master file' do
    expect(File.exist?('book.adoc')).to be true
  end

  it 'generates a .gitignore' do
    expect(File.exist?('.gitignore')).to be true
  end

  it 'generates a Gemfile' do
    expect(File.exist?('Gemfile')).to be true
  end

  it 'puts correct persie version in Gemfile' do
    content = File.read('Gemfile')
    expect(content).to match(/gem 'persie', '(\d+\.\d+\.\d+\.?\w*?\.\d+)'/m)
  end

  it 'generates a themes directory' do
    expect(Dir.exist?('themes')).to be true
  end

  it 'generates a builds directory' do
    expect(Dir.exist?('builds')).to be true
  end

  it 'generates a images directory' do
    expect(Dir.exist?('images')).to be true
  end

  it 'generates a tmp directory' do
    expect(Dir.exist?('tmp')).to be true
  end

  it 'generates a pdf.css file' do
    path = File.join 'themes', 'pdf', 'pdf.css'
    expect(File.exist? path).to be true
  end

  it 'generates a epub.css file' do
    path = File.join 'themes', 'epub', 'epub.css'
    expect(File.exist? path).to be true
  end

  it 'generates a style.css file for single html' do
    path = File.join 'builds', 'html', 'single', 'style.css'
    expect(File.exist? path).to be true
  end

  it 'generates a style.css file for multiple htmls' do
    path = File.join 'builds', 'html', 'multiple', 'style.css'
    expect(File.exist? path).to be true
  end

end
