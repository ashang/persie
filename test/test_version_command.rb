require_relative 'helper'

class VersionCommandTest < Minitest::Test

  def test_version_command_returns_correct_number
    assert_equal 'persie ' << ::Persie::VERSION, persie_command('version')
  end

end
