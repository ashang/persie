require 'helper'

class VersionCommandTest < Minitest::Test

  def test_version_command_returns_correct_number
    assert_equal ::Persie::VERSION, run_command('version')
  end

end
