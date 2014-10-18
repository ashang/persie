require 'persie'

SPEC_FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
A_BOOK_PATH = File.join(SPEC_FIXTURES_PATH, 'a-book')

# add a custom matcher, named `be_exists'
RSpec::Matchers.define :be_exists do |expected|
  match do |path|
    File.exist?(path)
  end
  failure_message do |path|
    "expected #{path} file/directory exists"
  end
end

# run a persie command
def persie_command(cmd)
  `#{::Persie::GEM_ROOT}/bin/persie #{cmd}`.chomp
end

# render inline Asciidoc string
def render_string(src, opts = {})
  opts[:doctype] = 'inline' unless opts.has_key? :doctype
  opts[:backend] = 'htmlbook' unless opts.has_key? :backend
  Asciidoctor.render(src, opts)
end
