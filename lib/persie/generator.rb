require 'thor'

module Persie
  class Generator < ::Thor::Group

    include ::Thor::Actions

    def self.source_root
      File.join(::Persie::GEM_ROOT, 'templates')
    end

    def copy_master_file
      copy_file 'book.adoc'
    end

    def copy_gitignore
      copy_file 'gitignore', '.gitignore'
    end

    def copy_book_files
      copy_file 'preface.adoc', 'manuscript/preface.adoc'
      copy_file 'chapter1.adoc', 'manuscript/chapter1.adoc'
      copy_file 'chapter2.adoc', 'manuscript/chapter2.adoc'
    end

    def create_theme_dir
      empty_directory 'theme/pdf'
      empty_directory 'theme/epub'
      empty_directory 'theme/mobi'
      empty_directory 'theme/site'
    end

    def create_images_dir
      empty_directory 'images'
    end

  end
end
