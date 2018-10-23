require "rubygems"
require "sinatra" 

ENV['RACK_ENV'] ||= 'development'

require File.expand_path '../app.rb', __FILE__

run BuilderApi