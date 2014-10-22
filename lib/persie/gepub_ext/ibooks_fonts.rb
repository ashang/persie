module GEPUB
  class Metadata

    def ibooks_specified_fonts
      @ibooks_specified_fonts.content || false
    end

    def ibooks_specified_fonts=(val)
      @ibooks_specified_fonts = Meta.new('meta', val, self, { 'property' => 'ibooks:specified-fonts' })
      (@content_nodes['meta'] ||= []) << @ibooks_specified_fonts
    end

  end

  class Package
    def_delegators :@metadata, :ibooks_specified_fonts
    def_delegators :@metadata, :ibooks_specified_fonts=
  end

  class Builder
    def ibooks_specified_fonts(val)
      @book.ibooks_specified_fonts = val
    end
  end
end
