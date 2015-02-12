namespace :archive do

  def strategy
    @strategy ||= OngrDeploy::Capistrano::Archive.new(
        self, fetch( :archive_strategy, OngrDeploy::Capistrano::Archive::DefaultStrategy )
      )
  end

  task :check do
    set :cache_path, "#{fetch :tmp_dir}/#{fetch :application}/#{fetch :branch }"

    run_locally do
      set :origin_revision, capture( :git, "rev-parse --short origin/#{fetch :branch }" ).chomp

      execute :mkdir, "-p", fetch( :cache_path )
    end

    on release_roles :all do
      execute :mkdir, "-p", repo_path
    end
  end

  task :pack_release do
    exclude = []

    fetch( :archive_exclude, [] ).each do |e|
      exclude << "--exclude=#{e}"
    end

    set :archive_path, "#{fetch :cache_path}/#{fetch :application}_#{fetch :origin_revision}.tar.gz"

    run_locally do
      execute :tar, "-c", "-z", "-f", fetch( :archive_path ), exclude.join( " " ), "."
      execute :ln, "-f", "-s", fetch( :archive_path ), "#{fetch :cache_path}/current"
    end

    invoke :"archive:cleanup"
  end

  task :create_release do
    if fetch( :archive_cache, false )
      run_locally do
        unless test "[ -L #{fetch :cache_path}/current ]"
          error "Deploy only allowed for already packed releases"
          exit 1
        end
      end
    else
      invoke :"archive:pack_release"
    end

    run_locally do
      unless test "[ -f #{fetch :cache_path}/current ]"
        error "Cache symlink is broken"
        exit 1
      end
    end

    on release_roles :all do
      execute :mkdir, "-p", release_path
      upload! "#{fetch :cache_path}/current", repo_path
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
      releases = capture( :ls, "-xtr", fetch( :cache_path ) ).split
      releases.reject! { |r| r =~ /current/ }

      if releases.count >= fetch( :keep_releases )
        expired = releases - releases.last( fetch :keep_releases )

        if expired.any?
          within fetch( :cache_path ) do
            execute :rm, "-rf", expired.join( " " )
          end
        end
      end
    end
  end

end

namespace :deploy do

  task :pack do
    invoke :"deploy:check"
    invoke :"archive:pack_release"
  end

end
