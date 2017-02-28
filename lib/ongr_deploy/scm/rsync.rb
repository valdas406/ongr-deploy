require "capistrano/scm/plugin"
require "redis"
require "redis-namespace"

module OngrDeploy

  module Capistrano

    class SCM

      class Rsync < ::Capistrano::SCM::Plugin

        def set_defaults
        end

        def define_tasks
          eval_rakefile File.expand_path( "../tasks/rsync.rake", __FILE__ )
        end

        def register_hooks
          # Extensions
          before "deploy:check", "rsync:check"
          before "deploy:check:linked_files", "rsync:create_params"
          after "deploy:new_release_path", "rsync:create_release"
          before "deploy:set_current_revision", "rsync:set_current_revision"
          after "deploy:published", "rsync:published"

          # Overrides
          Rake::Task["deploy:rollback_release_path"].clear

          after "deploy:rollback_release_path", "rsync:rollback_release_path"
        end

        def get_redis
          @redis ||= Redis.new(
            host: fetch( :redis_host, "localhost" ),
            port: fetch( :redis_port, 6379 ),
            db:   fetch( :redis_db, 0 )
          )

          begin
            @redis.ping
          rescue
            fail "REDIS CONNECTION ERROR"
          end

          @redis
        end

        def get_redis_nm
          @redis_nm ||= Redis::Namespace.new fetch( :cache_namespace ), redis: get_redis
        end

        def release
          backend.execute :cp, "-R", "#{repo_path}/.", release_path
        end

        def fetch_revision
          "####"
        end

      end

    end

  end

end
