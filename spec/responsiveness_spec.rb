# frozen_string_literal: true

require 'colorize'
require 'httparty'
require 'rspec'

cluster_endpoint = ENV['CLUSTER_ENDPOINT']

raise 'CLUSTER_ENDPOINT environment variable must be set to run integration tests' if cluster_endpoint.nil?

puts "Running integration tests for demo apps running in the Kubernetes cluster at:\n#{cluster_endpoint.blue}"

describe 'Demo App Integration Tests' do
  it 'tests responsiveness of [traefik] demo appliation' do
    url = "http://traefik.#{cluster_endpoint}"
    response = HTTParty.get(url)
    expect(response.code).to eq(200)
  end

  it 'tests responsiveness of [whoami] demo appliation' do
    url = "http://whoami.#{cluster_endpoint}"
    response = HTTParty.get(url)
    expect(response.code).to eq(200)
  end

  it 'tests responsiveness of [nginx-hello] demo appliation' do
    url = "http://nginx-hello.#{cluster_endpoint}"
    response = HTTParty.get(url)
    expect(response.code).to eq(200)
  end

  it 'tests responsiveness of [ubuntu-testbed] demo appliation' do
    url = "http://ubuntu-testbed.#{cluster_endpoint}"
    response = HTTParty.get(url)
    expect(response.code).to eq(200)
  end

  it 'tests responsiveness of [timestamp] demo appliation' do
    url = "http://timestamp.#{cluster_endpoint}"
    response = HTTParty.get(url)
    expect(response.code).to eq(200)
  end

  it 'tests that the timestamp server returns a valid JSON response' do
    url = "http://timestamp.#{cluster_endpoint}"
    response = HTTParty.get(url)
    body = JSON.parse(response.body)
    expect(body['message']).to eq('Automate all the things!')
    server_time = Time.at(body['timestamp'])
    expect(server_time).to be_within(30).of(Time.now)
    expect(body['timestamp'].to_s).to match(/\d{10}/)
  end
end

RSpec.configure do |config|
  config.formatter = :documentation
end
