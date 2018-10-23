class CuratorService
  def initialize(service)
    @service = service
  end

  def run(app, basename, rack)
    puts "[app, basename, rack] -> #{app} : #{basename} : #{rack}"
    Thread.new {
      set_env_vars(app, basename, rack)
    }
  end

  def set_env_vars(app, basename, rack)
    wait # App needs to be in a running state
    puts "[setting env vars]"
    %x{ convox env -a #{basename} --rack #{rack}| convox env set -a #{app} --rack #{rack} }
  end

private
  def wait
    while @service.current_app.dig('status') != 'running'
      sleep 10
    end
  end
end