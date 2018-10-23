class ConvoxService

  CONVOX_HOST = 'https://console.convox.com'.freeze

  attr_accessor :access_token, :app, :pr

  def initialize(access_token)
    @access_token = access_token
  end

  def build(url)
    api("/apps/#{app}/builds", method: :post) do |req|
      req.options.timeout = 60
      req.body = {
        manifest: 'docker-compose.yml',
        url: url
      }    
    end
  end

  def create(app_name, rack='wt/easybib-playground')
    # api('/apps', method: :post, request: :multipart) do |req|
    #   req.params['name'] = app_name
    #   req.params['generation'] = 1
    # end
    %x{ convox apps create #{app_name} -g 1 --rack #{rack} }
  end

  def app_name(base_name, pr)
    @pr  = pr
    @base_app_name = base_name
    @app = pr ? "#{base_name}-#{pr}" : base_name 
  end
  
  def app_exists?(base_name, pr)
    current_apps.include?(app_name(base_name, pr))
  end

  def basename
    @base_app_name
  end

  def create_tarball(tarball)
    require 'tempfile'
    tempfile = Tempfile.create(File.basename(tarball))
    tempfile.write File.read(tarball)
    response = api("/apps/#{@app}/objects/#{@app}.tgz", method: :post, request: :multipart) do |req|
                # req.options.timeout = 60
                # req.headers['Content-Type'] = 'octet/stream'
                req.headers['Content-Length'] = tempfile.size.to_s
                req.headers['Transfer-Encoding'] = 'chunked'
                req.body = Faraday::UploadIO.new(tempfile, 'multipart/form-data')
              end
    tempfile.close
    response
  end

  def current_app
    api("/apps/#{@app}")
  end

  def current_apps
    api('/apps').collect{|app| app.dig('name') }
  end

  def current_env_vars
    api("/apps/#{@base_app_name}/environment")
  end

  def current_rack(rack='wt/easybib-playground')
    @current_rack ||= rack
  end

  def fetch_app(name)
    api("/apps/#{name}")
  end

  def set_env_vars
    api("/apps/#{@app}/environment", method: :post) do |req|
      req.body = current_env_vars.map{|k,v| "#{k}=#{v}" }.join("\n")
    end
  end

private
  def api(url, method: :get, request: :url_encoded)
    conn =  Faraday.new(CONVOX_HOST) do |faraday|
              faraday.request request
              faraday.adapter Faraday.default_adapter
            end
    resp =  conn.send(method) do |req|
              req.url url
              req.headers['rack'] = @current_rack
              req.headers['Accept'] = 'application/json'
              req.headers['Authorization'] = "Basic #{@access_token}"
              yield(req) if block_given?
            end
    puts "#{resp.status} : #{JSON.parse(resp.body)}"
    JSON.parse(resp.body)
  end
end