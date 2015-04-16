require "capistrano/scm"

load File.expand_path( "../../../tasks/scm/rsync.rake", __FILE__ )

module OngrDeploy

  module Capistrano

    class Rsync < ::Capistrano::SCM

      module DefaultStrategy

        def release
          context.execute :cp, "-R", "#{repo_path}/.", release_path
        end

        def fetch_revision
          "" # context.capture :git, "rev-parse --short origin/#{fetch :branch}"
        end

      end

    end

  end

end
