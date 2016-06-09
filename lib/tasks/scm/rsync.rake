require "yaml"
require "deep_merge"

namespace :rsync do

  def strategy
    @strategy ||= OngrDeploy::Capistrano::Rsync.new(
        self, fetch( :strategy, OngrDeploy::Capistrano::Rsync::DefaultStrategy )
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

    fetch( :exclude, [] ).each do |e|
      exclude << "--exclude=#{e}"
    end

    set :archive_path, "#{fetch :cache_path}/#{fetch :origin_revision}/"

    run_locally do
      execute :mkdir, "-p", fetch( :archive_path )
      execute :rsync, "-rlp", "--delete", "--delete-excluded", exclude.join( " " ), "./", fetch( :archive_path )
      execute :rm, "-f", "#{fetch :cache_path}/current"
      execute :ln, "-s", fetch( :archive_path ), "#{fetch :cache_path}/current"
    end

    invoke :"rsync:cleanup"
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
      unless test "[ -d #{fetch :cache_path}/current ]"
        error "Cache symlink is broken"
        exit 1
      end
    end

    on release_roles :all do |host|
      execute :mkdir, "-p", release_path

      run_locally do
        execute :rsync, "-crlpz", "--delete", "--stats", "#{fetch :cache_path}/current/", "#{host.username}@#{host.hostname}:#{repo_path}"
      end

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
    invoke :"rsync:pack_release"
  end

  task :genconf do
    on release_roles :all do
      within release_path do
        fqdn      = capture :hostname, "-f"
        dist      = YAML::load File.read( "app/config/parameters.yml.dist" )
        dist_env  = fqdn.include?( "stage" ) ? "stage" : "live"
        dist_list = ["parameters.yml.#{dist_env}", "parameters.yml.#{dist_env}.#{fqdn[/([a-z\-]+)/,1]}"]

        dist_list.each do |df|
          if File.exists? "app/config/#{df}"
            overrides = YAML::load File.read( "app/config/#{df}" )

            dist.deep_merge! overrides
          end
        end

        content = StringIO.new dist.to_yaml

        execute "cp", "#{fetch(:deploy_to)}/shared/app/config/parameters.yml", "#{fetch(:deploy_to)}/shared/app/config/parameters-#{Time.new.strftime "%Y%m%d%H%M"}.yml"
        upload! content, "#{fetch(:deploy_to)}/shared/app/config/parameters.yml"
        execute "chmod", "664", "#{fetch(:deploy_to)}/shared/app/config/parameters.yml"
      end
    end
  end

end
