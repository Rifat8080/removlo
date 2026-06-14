max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }

threads min_threads_count, max_threads_count

environment ENV.fetch("RAILS_ENV") { "production" }

bind "tcp://127.0.0.1:3000"

pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

workers ENV.fetch("WEB_CONCURRENCY") { 1 }

preload_app!

plugin :tmp_restart