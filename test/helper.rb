$:.unshift File.expand_path('../../lib', __FILE__)

require 'minitest/autorun'
require 'minitest/pride'
require 'persie'


def persie_command(cmd)
  `#{::Persie::GEM_ROOT}/bin/persie #{cmd}`.chomp
end
