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

puts "Starting timestamp server..."

class TimeStampServer < Sinatra::Base

  set :bind, '0.0.0.0'
  get '/' do
    content_type :json
    { message: 'Automate all the things!', timestamp: Time.now.to_i }.to_json
  end

  get '/health' do
    'OK'
  end
end

TimeStampServer.run!
