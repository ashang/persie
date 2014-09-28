require_relative 'spec_helper'

describe 'Cli#version' do
  it 'shows corrent persie version' do
    shows = persie_command 'version'
    expect(shows).to eq("persie #{::Persie::VERSION}")
  end
end
