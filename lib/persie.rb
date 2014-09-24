require_relative 'persie/cli'

Encoding.default_internal = 'utf-8'
Encoding.default_external = 'utf-8'

module Persie
  GEM_ROOT      = File.expand_path('../../', __FILE__)
  TEMPLATES_DIR = File.join(GEM_ROOT, 'templates')

  def self.ruby_platform_warning
    host = RbConfig::CONFIG['host_os']
    if host =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      $stderr.puts 'Sorry, you cannot use persie on Windows.'
      exit 1
    end
  end

  def self.ruby_version_warning
    if RUBY_VERSION < '1.9.3'
      $stderr.puts "Your Ruby version(#{RUBY_VERSION}) is NOT supported, please upgrade!"
      exit 2
    end
  end

  def self.require_plugins
    plugins = File.join(Dir.pwd, 'plugins', '*.rb')

    Dir.glob(plugins) do |path|
      require path
    end
  end
end
