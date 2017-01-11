require "capistrano/scm/plugin"

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
          before "deploy:check", "rsync:check"
          after "deploy:new_release_path", "rsync:create_release"
          before "deploy:set_current_revision", "rsync:set_current_revision"
        end

        def release
          backend.execute :cp, "-R", "#{repo_path}/.", release_path
        end

        def fetch_revision
          "####" # backend.capture :cat, "version.txt"
        end

      end

    end

  end

end
