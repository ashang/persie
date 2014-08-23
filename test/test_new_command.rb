require 'fileutils'
require 'helper'

class NewCommandTest < Minitest::Test

  BOOK_SLUG = 'sample-book'
  TEST_DIR = File.join(::Persie::GEM_ROOT, 'test')
  BOOK_DIR = File.join(TEST_DIR, BOOK_SLUG)

  def setup
    FileUtils.cd(TEST_DIR) do
      run_command("new #{BOOK_SLUG}")
    end
    FileUtils.cd BOOK_DIR
  end

  def teardown
    FileUtils.remove_dir BOOK_DIR
    FileUtils.cd ::Persie::GEM_ROOT
  end

  def test_book_file_exsit
    assert_equal true, File.exist?('book.adoc')
  end

  def test_theme_dir_exist
    assert_equal true, File.exist?('theme')
  end

end
