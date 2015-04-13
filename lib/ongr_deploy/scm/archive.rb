require "capistrano/scm"

load File.expand_path( "../../../tasks/scm/archive.rake", __FILE__ )

module OngrDeploy

  module Capistrano

    class Archive < ::Capistrano::SCM

      module DefaultStrategy

        def release
          context.execute :tar, "-xzf", "#{repo_path}/current", "-C", release_path
        end

        def fetch_revision
          "" # context.capture :git, "rev-parse --short origin/#{fetch :branch}"
        end

      end

    end

  end

end
