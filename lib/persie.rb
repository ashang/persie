require_relative 'persie/cli'

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
end
