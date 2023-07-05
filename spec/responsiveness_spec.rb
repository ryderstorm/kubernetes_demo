# frozen_string_literal: true

require 'colorize'
require 'httparty'
require 'rspec'

cluster_endpoint = ENV['CLUSTER_ENDPOINT']

raise 'CLUSTER_ENDPOINT environment variable must be set to run integration tests' if cluster_endpoint.nil?

puts "Running integration tests for demo apps running in the Kubernetes cluster at:\n#{cluster_endpoint.blue}"

describe 'Demo App Integration Tests' do
  app_domains = %w[traefik whoami game nginx-hello ubuntu-testbed timestamp]
  app_domains.each do |app_domain|
    it "tests that the #{app_domain} app is running" do
      url = "http://#{app_domain}.#{cluster_endpoint}"
      puts "\n  Testing url: #{url.blue}"
      response = HTTParty.get(url, timeout: 2)
      expect(response.code).to eq(200), "Expected #{url.blue} to return 200, got #{response.code} | #{response.body}"
    end
  end

  it 'tests that the timestamp server returns a valid JSON response' do
    url = "http://timestamp.#{cluster_endpoint}"
    response = HTTParty.get(url, timeout: 2)
    expect(response.code).to eq(200)
    puts "\n  Testing url: #{url.blue}"
    body = JSON.parse(response.body)
    expect(body['message']).to eq('Automate all the things!')
    server_time = Time.at(body['timestamp'])
    expect(server_time).to be_within(30).of(Time.now)
    expect(body['timestamp'].to_s).to match(/\d{10}/)
  end

  it 'tests that the timestamp server health endpoint returns a valid JSON response' do
    url = "http://timestamp.#{cluster_endpoint}/health"
    response = HTTParty.get(url, timeout: 2)
    puts "\n  Testing url: #{url.blue}"
    expect(response.code).to eq(200)
    expect(response.body).to eq('OK')
  end

  it 'tests that the timestamp server version endpoint returns a valid JSON response' do
    url = "http://timestamp.#{cluster_endpoint}/version"
    response = HTTParty.get(url, timeout: 2)
    puts "\n  Testing url: #{url.blue}"
    body = JSON.parse(response.body)
    expect(response.code).to eq(200), "Expected #{url.blue} to return 200, got #{response.code} | #{response.body}"
    expect(body['version']).to match(/^[a-f0-9]{7}$/)
    expect(body['build_time']).to match(/\d{10}/)
    expect(body['pretty_build_time']).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/)
  end
end

RSpec.configure do |config|
  config.formatter = :documentation
end
