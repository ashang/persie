# For sample generation, do some dirty hacks.

module Asciidoctor

  class AbstractBlock
    # Get an array of sample sections.
    def sample_sections
      @blocks.select { |b| b.context == :section && b.sample? }
    end
  end

  class Document
    # Get converted sample contents.
    def sample_content
      @attributes.delete('title')
      self.sections.select { |s| s.sample? }
                   .map { |s| s.convert } * "\n"
    end
  end

  class Section
    def sample=(bool)
      @sample = bool
    end

    # Whether this section is in sample.
    #
    # FIXME: Not quite working when there are multi-parts.
    #        If set `:sample:' on part, all sections in this part are displayed.
    #        If set `:sample:' on top-level section within this part, no affect!
    def sample?
      if self.attributes.has_key?(:attribute_entries)
        self.attributes[:attribute_entries].each do |entry|
          if entry.name == 'sample' && entry.value != nil
            self.sample = true
            downto_subsections(self.sections)
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
