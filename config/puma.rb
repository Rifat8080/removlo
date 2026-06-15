# Puma configuration. See https://puma.io/puma/Puma/DSL.html

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count)
threads min_threads_count, max_threads_count

environment ENV.fetch("RAILS_ENV", "development")

if ENV.fetch("RAILS_ENV", "development") == "production"
  bind ENV.fetch("BIND", "tcp://127.0.0.1:#{ENV.fetch('PORT', 3000)}")
else
  port ENV.fetch("PORT", 3000)
end

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

plugin :tmp_restart

workers_count = ENV.fetch("WEB_CONCURRENCY", "0").to_i
if workers_count.positive?
  workers workers_count
  preload_app!
end
