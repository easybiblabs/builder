require 'base64'
require 'faraday'
require 'json'
require 'pry' if development?
require 'sinatra'

require_relative 'helpers'
require_relative 'services/convox_service'
require_relative 'services/curator_service'
require_relative 'response'

abort('Invalid CONVOX_ACCESS_TOKEN') if ENV['CONVOX_ACCESS_TOKEN'].nil?

class BuilderApi < Sinatra::Application
  include Response
  before do
    validate_content_type
    parse_params
    set_current_rack
  end

  after do
    content_type :json
  end

  configure do
    enable :logging
    set :environment, ENV['RACK_ENV'] || 'development'
    set :convox_access_token, ENV['CONVOX_ACCESS_TOKEN']
    set :convox_service, ConvoxService.new(Base64.encode64("convox:#{convox_access_token}"))
    set :curator_service, CuratorService.new(settings.convox_service)
    set :server, :puma
  end

  get '/' do
    json_response(motd: 'Build all the things...')
  end

  get '/health' do
    json_response(status: 'ok')
  end

  post '/' do
    validate_app
    # validate_url
    validate_app_existence
    settings.curator_service.run(app_name, settings.convox_service.basename, settings.convox_service.current_rack)
    json_response(status: 'ok', app_name: app_name, rack: settings.convox_service.current_rack)
  end
end