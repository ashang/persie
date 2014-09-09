# For sample generation, do some dirty hacks.

module Asciidoctor

  class Section
    # Whether this section is in sample.
    def sample?
      if self.attributes.has_key? :attribute_entries
        self.attributes[:attribute_entries].each do |entry|
          return true if entry.name == 'sample'
        end
      end

      false
    end
  end

  class Document
    # Get converted sample contents.
    def sample_content
      @attributes.delete('title')
      self.sections.select { |s| s.sample? }
                   .map { |s| s.convert } * "\n"
    end

    # Get an array of sample sections.
    def sample_sections
      self.sections.select { |s| s.sample? }
    end
  end

end
