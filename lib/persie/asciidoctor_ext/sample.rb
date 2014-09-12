# For sample generation, do some dirty hacks.

module Asciidoctor

  class AbstractBlock
    # Get an array of sample sections.
    def sample_sections
      @blocks.reject! { |b| b.context == :section && !b.sample? }
      @blocks.select { |b| b.context == :section && b.sample? }
    end
  end

  class Document
    # Get converted sample contents.
    def sample_content
      @attributes.delete('title')
      self.sample_sections.map { |s| s.convert } * "\n"
    end
  end

  class Section

    def sample=(bool)
      @sample = bool
    end

    # Whether this section is in sample.
    def sample?
      if self.attributes.has_key?(:attribute_entries)
        self.attributes[:attribute_entries].each do |entry|
          if entry.name == 'sample' && entry.value != nil
            self.sample = true
            # Not down to top level sections in a part
            downto_subsections(self.sections) unless self.level == 0
          end
        end
      end

      @sample
    end

    private

    def downto_subsections(sections)
      if sections.size > 0
        sections.each do |s|
          s.sample = true
          downto_subsections(s.sections)
        end
      end
    end
  end

end
