require 'persie'

def persie_command(cmd)
  `#{::Persie::GEM_ROOT}/bin/persie #{cmd}`.chomp
end

def render_string(src, opts = {})
  opts[:doctype] = 'inline' unless opts.has_key? :doctype
  opts[:backend] = 'htmlbook' unless opts.has_key? :backend
  Asciidoctor.render(src, opts)
end
