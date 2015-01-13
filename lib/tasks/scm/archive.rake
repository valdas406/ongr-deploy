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

  task :set_archive do
    run_locally do
      set :archive_revision, capture( "git", "rev-parse --short origin/#{fetch( :branch )}" ).chomp
    end

    set :archive_name, [fetch( :application ),fetch( :branch ),fetch( :archive_revision )].join( "_" ) << ".tar.gz"
    set :archive_path, [fetch( :tmp_dir ),fetch( :archive_name )].join( "/" )
  end

  task pack_release: :set_archive do
    exclude = []

    fetch( :archive_exclude, [] ).each do |e|
      exclude << "--exclude=#{e}"
    end

    run_locally do
      execute "tar", "-c", "-z", "-f", fetch( :archive_path ), exclude.join( " " ), "."
    end
  end

  task create_release: :set_archive do
    run_locally do
      unless test "[ -f #{fetch( :archive_path )} ]"
        invoke :"archive:pack_release"
      end
    end

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
