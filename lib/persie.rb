require_relative 'persie/cli'
require_relative 'persie/generator'
require_relative 'persie/ui'
require_relative 'persie/htmlbook'
require_relative 'persie/book'
require_relative 'persie/version'

module Persie
  GEM_ROOT      = File.expand_path('../../', __FILE__)
  TEMPLATES_DIR = File.join(GEM_ROOT, 'templates')
end
