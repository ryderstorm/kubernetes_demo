# frozen_string_literal: true

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'sinatra', require: false
  gem 'sinatra-contrib', require: false
  gem 'json', require: true
  gem 'puma', require: true
end

require 'sinatra/base'
require 'sinatra/contrib'

puts 'Starting timestamp server...'

class TimeStampServer < Sinatra::Base
  set :bind, '0.0.0.0'
  helpers do
    def timestamp_response(message = 'Automate all the things!')
      { message: message, timestamp: Time.now.to_i }.to_json
    end
  end
  get '/' do
    content_type :json
    timestamp_response
  end

  get '/timestamp' do
    content_type :json
    timestamp_response
  end

  get '/health' do
    'OK'
  end

  get '/version' do
    content_type :json
    version_file = 'VERSION'
    timestamp_file = 'TIMESTAMP'
    version = File.exist?(version_file) ? File.read(version_file).strip : 'unknown'
    build_time = File.exist?(timestamp_file) ? File.read(timestamp_file).strip : 'unknown'
    pretty_build_time = Time.at(build_time.to_i).utc.strftime('%Y-%m-%d %H:%M:%S UTC')
    { version: version, build_time: build_time, pretty_build_time: pretty_build_time }.to_json
  end
end

TimeStampServer.run!
