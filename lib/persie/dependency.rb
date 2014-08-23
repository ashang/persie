module Persie
  module Dependency

    def self.prince_installed?
      installed? 'prince'
    end

    def self.kindlegen_installed?
      installed? 'kindlegen'
    end

    def self.installed?(cmd)
      return true if which(cmd)
      false
    end

    # Finds the executable.
    def self.which(cmd)
      system "which #{cmd} > /dev/null 2>&1"
    end
  end
end
