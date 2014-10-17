require 'thor'
require 'uuid'

require 'time'

module Persie
  class Generator < ::Thor::Group

    include ::Thor::Actions

    def self.source_root
      File.join(::Persie::GEM_ROOT, 'templates')
    end

    def copy_master_file
      template 'book.adoc.erb', 'book.adoc'
    end

    def copy_gitignore
      copy_file 'gitignore.txt', '.gitignore'
    end

    def copy_gemfile
      copy_file 'Gemfile.txt', 'Gemfile'
    end

    def copy_book_files
      copy_file 'preface.adoc', 'manuscript/preface.adoc'
      copy_file 'chapter1.adoc', 'manuscript/chapter1.adoc'
      copy_file 'chapter2.adoc', 'manuscript/chapter2.adoc'
    end

    def create_theme_dirs
      empty_directory 'themes/pdf'
      empty_directory 'themes/epub'
      empty_directory 'themes/html'
    end

    def create_build_dir
      empty_directory 'builds'
    end

    def copy_stylesheets
      copy_file 'stylesheets/pdf.css', 'themes/pdf/pdf.css'
      copy_file 'stylesheets/epub.css', 'themes/epub/epub.css'
      copy_file 'stylesheets/html.css', 'builds/html/single/style.css'
      copy_file 'stylesheets/html.css', 'builds/html/multiple/style.css'
    end

    def create_tmp_dir
      empty_directory 'tmp'
    end

    def create_images_dir
      empty_directory 'images'
    end

    def create_plugins_dir
      empty_directory 'plugins'
    end

    private

    def uuid
      UUID.new.generate(:urn)
    end

    def time_now
      Time.now.iso8601
    end

  end
end
