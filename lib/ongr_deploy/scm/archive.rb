require "capistrano/scm"

load File.expand_path( "../../../tasks/scm/archive.rake", __FILE__ )

module OngrDeploy

  module Capistrano

  class Archive < ::Capistrano::SCM

      module DefaultStrategy

        def release
          context.execute "tar", "-x", "-z", "-f", "#{repo_path}/#{fetch( :archive_name )}", "-C", release_path
        end

        def fetch_revision
          context.capture "git", "rev-parse --short #{fetch( :branch )}"
        end

      end

    end

  end

end
