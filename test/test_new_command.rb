require 'fileutils'
require_relative 'helper'

class NewCommandTest < Minitest::Test

  BOOK_SLUG = 'sample-book'
  TEST_DIR = File.join(::Persie::GEM_ROOT, 'test')
  BOOK_DIR = File.join(TEST_DIR, BOOK_SLUG)

  def setup
    FileUtils.cd(TEST_DIR) do
      persie_command("new #{BOOK_SLUG}")
    end
    FileUtils.cd BOOK_DIR
  end

  def teardown
    FileUtils.remove_dir BOOK_DIR
    FileUtils.cd ::Persie::GEM_ROOT
  end

  def test_master_file_exsit
    assert_equal true, File.exist?('book.adoc')
  end

  def test_gitignore_file_exsit
    assert_equal true, File.exist?('.gitignore')
  end

  def test_gemfile_exsit
    assert_equal true, File.exist?('Gemfile')
  end

  def test_gemfile_has_set_correct_persie_version
    File.read('Gemfile').match /gem 'persie', '(\d+\.\d+\.\d+\.?\w*)'/m
    assert_equal ::Persie::VERSION, $+
  end

  def test_themes_dir_exist
    assert_equal true, Dir.exist?('themes')
  end

  def test_builds_dir_exist
    assert_equal true, Dir.exist?('builds')
  end

  def test_images_dir_exist
    assert_equal true, Dir.exist?('images')
  end

  def test_plugins_dir_exist
    assert_equal true, Dir.exist?('plugins')
  end

  def test_tmp_dir_exist
    assert_equal true, Dir.exist?('tmp')
  end

end
