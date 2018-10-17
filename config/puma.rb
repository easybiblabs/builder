workers Integer(ENV['PUMA_WORKERS'] || 2)
threads_count = Integer(ENV['PUMA_THREAD_COUNT'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['SERVICE_PORT'] || 3000
environment ENV['RACK_ENV']     || 'development'
