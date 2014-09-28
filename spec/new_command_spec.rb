require_relative 'spec_helper'
require 'fileutils'

describe 'Cli#new' do

  before(:all) do
    book_slug = 'sample-book'
    tmp_dir = File.join(::Persie::GEM_ROOT, 'tmp')
    book_dir = File.join(tmp_dir, book_slug)

    FileUtils.mkdir_p(tmp_dir) unless Dir.exist? tmp_dir
    FileUtils.remove_dir(book_dir) if Dir.exist? book_dir

    FileUtils.cd(tmp_dir) do
      persie_command "new #{book_slug}"
    end

    FileUtils.cd book_dir
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
    expect(content).to match(/gem 'persie', '(\d+\.\d+\.\d+\.?\w*)'/m)
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

  it 'generates a plugins directory' do
    expect(Dir.exist?('plugins')).to be true
  end

  it 'generates a tmp directory' do
    expect(Dir.exist?('tmp')).to be true
  end

end
