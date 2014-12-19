namespace :archive do

  def strategy
    @strategy ||= OngrDeploy::Capistrano::Archive.new(
        self, fetch( :archive_strategy, OngrDeploy::Capistrano::Archive::DefaultStrategy )
      )
  end

  task :check do
    on release_roles :all do
      execute :mkdir, "-p", repo_path
    end
  end

  task :pack_release do
    set :archive_name, "#{fetch( :application )}_#{fetch( :branch )}.tar.gz"
    set :archive_path, "#{fetch( :tmp_dir )}/#{fetch( :archive_name )}"

    run_locally do
      execute "tar", "-c", "-z", "-f", fetch( :archive_path ), "."
    end
  end

  task create_release: :pack_release do
    on release_roles :all do
      execute :mkdir, "-p", release_path
      upload! fetch( :archive_path ), repo_path
      invoke :"archive:cleanup"
      strategy.release
    end
  end

  task :set_current_revision do
    on release_roles :all do
      within release_path do
        set :current_revision, strategy.fetch_revision
      end
    end
  end

  task :cleanup do
    run_locally do
      execute "rm", "-f", fetch( :archive_path )
    end
  end

end
