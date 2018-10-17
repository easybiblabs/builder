require 'pry'

class Curator
  REPO_ROOT = 'repos'.freeze
  TARBALL_ROOT = 'tarballs'.freeze

  class << self
    def run(build_attrs:, github_client:, convox_service:)
      Thread.new{ self.new(build_attrs, github_client, convox_service).run }
    end
  end

  def initialize(build_attrs, github_client, convox_service)
    @app_name = build_attrs[:app_name]
    @branch = build_attrs[:branch]
    @rack = build_attrs[:rack]
    @url = build_attrs[:url]
    @type = build_attrs[:type]
    @github_api  = github_client
    @convox_service = convox_service
  end

  def deploy
    puts "[deploy]"
    Dir.chdir("#{REPO_ROOT}/#{@app_name}") do
      # Found a bug in convox. ( https://github.com/convox/rack/pull/2737 )
      # DD opened an issue and the following line is necessary until it's merged.
      %x{ sed -i '/.dockerignore/d' ./.dockerignore }
      @type == 'PHP' ? init_php_app : init_ruby_app
      # %x{ convox deploy -f docker-compose.staging.yml --id --app #{@service.app} --rack #{@rack} }
    end
  end

  def clone
    puts "[cloning] : #{@app_name}"
    `cd #{REPO_ROOT} && git clone #{@url} #{@app_name}`
  end

  def checkout
    puts "[checkout]"
    `cd #{REPO_ROOT}/#{@app_name} && git checkout #{@branch}`
  end

  def create_directory
    %x{ mkdir -p /repos/#{@app_name} } unless Dir.exists?("/repos/#{@app_name}")
  end

  def init_php_app
    Dir.chdir("#{REPO_ROOT}/#{@app_name}") do
      %x{ ./composer.phar install --no-suggest --optimize-autoloader --no-dev && ./composer.phar dumpautoload }
    end
  end

  def init_ruby_app
    puts "[init ruby]"
    Dir.chdir("#{REPO_ROOT}/#{TARBALL_ROOT}") do
      puts %x{ tar -zcvf #{@convox_service.app}.tgz ../#{@app_name}/ --exclude-vcs }
      puts %x{ ls -hasl }
    end
    # @service.build("#{REPO_ROOT}/#{TARBALL_ROOT}/#{@app_name}.tgz")
    # puts %x{ gem install rake }
    # puts %x{ sed -i '/ruby\s./d' Gemfile }
    # puts %x{ bundle install && bundle exec rake RAILS_ENV=production assets:precompile }
  end

  def run
    repo = "easybib/#{@app_name}"
    pull_request = @github_api.pull_request(repo, @convox_service.pr)
    ref = @github_api.archive_link(repo, ref: pull_request[:head][:ref])
    Dir.chdir("#{REPO_ROOT}/#{TARBALL_ROOT}"){ 
      puts %x{ curl -L #{ref} > #{@convox_service.app}.tar.gz }
      Dir.mkdir(@convox_service.app) unless Dir.exists?(@convox_service.app)
      puts %x{ tar -xzf #{@convox_service.app}.tar.gz -C #{@convox_service.app} --strip-components=1 }
      puts %x{ tar -zcf #{@convox_service.pr}.tgz -C #{@convox_service.app}/ . }
      puts "[send_tarball]"
      puts response = send_tarball(@convox_service, "#{@convox_service.pr}.tgz")
      url = JSON.parse(response.body)['Url']
      puts "[Url] #{url}"
      set_env_vars
      puts "curl -H 'rack: #{@convox_service.current_rack}' -H 'Authorization: Basic #{@convox_service.access_token}' -X POST 'https://console.convox.com/apps/#{@convox_service.app}/builds?url=#{url}&manifest=docker-compose.yml'"
      build = %x{ curl -H 'rack: #{@convox_service.current_rack}' -H 'Authorization: Basic #{@convox_service.access_token}' -X POST 'https://console.convox.com/apps/#{@convox_service.app}/builds?url=#{url}&manifest=docker-compose.yml' }
      puts JSON.parse(build)['id']
    }
    # tarball = @convox_service.create_tarball("#{REPO_ROOT}/#{TARBALL_ROOT}/#{@convox_service.pr}.tgz")
    # puts tarball['Url']
    # puts @convox_service.build(tarball['Url'])
    # deploy
  end

  def send_tarball(service, tarball)
    require 'net/http'
    require 'uri'

    uri = URI.parse("https://console.convox.com/apps/#{service.app}/objects/#{tarball}")
    request = Net::HTTP::Post.new(uri)
    request["Rack"] = service.current_rack
    request["Authorization"] = "Basic #{service.access_token.delete("\r\n")}"
    request.body = ""
    request.body << File.read(tarball)

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
  end

  def set_env_vars
    wait # App needs to be in a running state
    puts "[setting env vars]"
    @convox_service.set_env_vars
    wait # App needs to be in a running state
  end

  def wait
    while @convox_service.current_app.dig('status') != 'running'
      sleep 10
    end
  end
end