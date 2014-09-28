require 'persie'

def persie_command(cmd)
  `#{::Persie::GEM_ROOT}/bin/persie #{cmd}`.chomp
end
