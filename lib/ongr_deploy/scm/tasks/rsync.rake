require "yaml"
require "deep_merge"

rsync_plugin = self

namespace :rsync do

  # Extensions

  task :init do
    set :cache_namespace, [fetch(:application), fetch( :stage )].join( "_" )
    set :cache_path, [fetch( :tmp_dir ), fetch( :cache_namespace )].join( "/" )

    artifact_db = rsync_plugin.get_redis_nm.keys "*"

    fail "ARTIFACT DB IS EMPTY" if artifact_db.empty?

    artifact_db.map! { |i| i.to_i }
    artifact_db.sort!

    if fetch( :deploying, false )
      set :artifact_timestamp, artifact_db.last.to_s
    else
      artifact_db.keep_if { |i| rsync_plugin.get_redis_nm.hget( i, :deploy ) == "true" }

      fail "MIN RELEASE COUNT IS 2 FOR ROLLBACK" if artifact_db.size < 2

      set :artifact_timestamp, artifact_db[-2].to_s
      set :delete_timestamp, artifact_db[-1].to_s
    end

    set :artifact_path, [fetch( :cache_path ), fetch( :artifact_timestamp )].join( "/" )
  end

  task check: :init do
    run_locally do
      unless test "[ -d #{fetch :artifact_path} ]"
        error "Cache symlink is broken"
        exit 1
      end
    end

    on release_roles :all do
      execute :mkdir, "-p", repo_path
    end
  end

  task :create_params do
    if fetch :ongr_create_params, false
      params = nil

      Dir.chdir fetch( :artifact_path ) do
        unless File.exists? "app/config/parameters.yml.dist"
          fail "parameters.yml.dist NOT FOUND"
        end

        params = YAML::load File.read( "app/config/parameters.yml.dist" )

        unless params
          fail "SYNTAX ERROR ON YML FILE parameters.yml.dist"
        end
      end

      on release_roles( :all ) do
        fqdn = capture( :hostname, "-f" )[/([a-z\-]+)/,1]

        Dir.chdir fetch( :artifact_path ) do
          ["parameters.yml.#{fetch :stage}", "parameters.yml.#{fetch :stage}.#{fqdn}"].each do |yml|
            if File.exists? "app/config/#{yml}"
              override = YAML::load File.read "app/config/#{yml}"

              unless override
                fail "SYNTAX ERROR ON YML FILE #{yml}"
              end

              params.deep_merge! override
            end
          end
        end

        content = StringIO.new params.to_yaml

        within shared_path do
          if test "[ -f #{shared_path}/app/config/parameters.yml ]"
            execute :cp, "app/config/parameters.yml", "app/config/parameters-#{Time.new.strftime "%Y%m%d%H%M"}.yml"
          end

          upload! content, "#{shared_path}/app/config/parameters.yml"
          execute :chmod, "664", "app/config/parameters.yml"
        end
      end
    end
  end

  task :create_release do
    set_release_path fetch( :artifact_timestamp )

    on release_roles( :all ) do |host|
      execute :mkdir, "-p", release_path

      run_locally do
        execute :rsync, "-crlpz", "--delete", "--stats", "#{fetch :artifact_path}/", "#{host.username}@#{host.hostname}:#{repo_path}"
      end
    end

    on release_roles( :all ) do
      rsync_plugin.release
    end
  end

  task :set_current_revision do
    on release_roles( :all ) do
      within repo_path do
        set :current_revision, rsync_plugin.fetch_revision
      end
    end
  end

  task :published do
    rsync_plugin.get_redis.set fetch( :cache_namespace ), fetch( :artifact_timestamp )

    if fetch( :deploying, false )
      rsync_plugin.get_redis_nm.hset fetch( :artifact_timestamp ), :deploy, true
    else
      rsync_plugin.get_redis_nm.del fetch( :delete_timestamp )
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

  # Overrides

  task :rollback_release_path do
    set_release_path fetch( :artifact_timestamp )
    set :rollback_timestamp, fetch( :artifact_timestamp )
  end

end

namespace :artifact do

  task :init do
    set :cache_namespace, [fetch(:application), fetch( :stage )].join( "_" )
    set :cache_path, [fetch( :tmp_dir ), fetch( :cache_namespace )].join( "/" )
    set :artifact_timestamp, now
    set :artifact_path, [fetch( :cache_path ), fetch( :artifact_timestamp )].join( "/" )
  end

  task pack: :init do
    exclude = []

    fetch( :ongr_exclude, [] ).each do |e|
      exclude << "--exclude=#{e}"
    end

    run_locally do
      execute :mkdir, "-p", fetch( :artifact_path )
      execute :rsync, "-rlp", "--delete", "--delete-excluded", exclude.join( " " ), "./", fetch( :artifact_path )
    end

    rsync_plugin.get_redis_nm.hset fetch( :artifact_timestamp ), :pack, true
  end

end