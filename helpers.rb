helpers do
  def app_name
    return '' if request.request_method == 'GET'
    settings.convox_service.app_name(params.dig('app_name'), params.dig('pr'))
  end

  def parse_params
    return if request.request_method == 'GET'
    @params = JSON.parse(request.body.read)
  end

  def set_current_rack
    return '' if request.request_method == 'GET'
    settings.convox_service.current_rack(params.dig('rack')) if params.dig('rack')
  end

  def validate_app
    return '' if request.request_method == 'GET'
    errors = []
    errors.push(name: 'invalid') if params.dig('app_name').nil?
    errors.push(pr: 'invalid') if params.dig('pr').nil?
    halt 400, json_response(errors) unless errors.empty?
  end

  def validate_app_existence
    name = params.dig('app_name')
    pr   = params.dig('pr')
    halt 200, json_response(status: 'ok', app_name: settings.convox_service.app, rack: settings.convox_service.current_rack) if settings.convox_service.app_exists?(name, pr)
    settings.convox_service.create(settings.convox_service.app, settings.convox_service.current_rack)  
  end

  def validate_content_type
    return if request.request_method == 'GET'
    halt 415, json_response(message: 'invalid content type') unless request.content_type == 'application/json'
  end

  def validate_url
    halt 400, json_response(url: 'invalid') if params.dig('url').nil?
  end
end