require 'webrick'

module Persie
  module Server

    include WEBrick

    def self.start(dir)
      destination = File.join(Dir.pwd, 'builds', 'site', dir)

      # recreate NondisclosureName under utf-8 circumstance
      fh_option = WEBrick::Config::FileHandler
      fh_option[:NondisclosureName] = ['.ht*','~*']

      s = HTTPServer.new(
        :Port => 9527,
        :BindAddress => '0.0.0.0',
      )

      s.mount('/', HTTPServlet::FileHandler, destination, fh_option)
      t = Thread.new { s.start }
      trap("INT") { s.shutdown }
      t.join()
    end

  end
end
