require "yaml"
require "deep_merge"

rsync_plugin = self

namespace :rsync do

  task :init do
    set_if_empty :cache_namespace, [fetch(:application), fetch( :stage )].join( "_" )
    set_if_empty :cache_path, [fetch( :tmp_dir ), fetch( :cache_namespace )].join( "/" )
    set_if_empty :local_release_path, "#{fetch :local_base}/current"
  end

  task check: :init do
    run_locally do
      unless test "[ -d #{fetch :local_base}/current ]"
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

      Dir.chdir fetch( :local_release_path ) do
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

        Dir.chdir fetch( :local_release_path ) do
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
    on release_roles( :all ) do |host|
      execute :mkdir, "-p", release_path

      run_locally do
        execute :rsync, "-crlpz", "--delete", "--stats", "#{fetch :local_release_path}/", "#{host.username}@#{host.hostname}:#{repo_path}"
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

namespace :artifact do

  task :init do
    set_if_empty :cache_namespace, [fetch(:application), fetch( :stage )].join( "_" )
    set_if_empty :cache_path, [fetch( :tmp_dir ), fetch( :cache_namespace )].join( "/" )
  end

  task pack: :init do
    exclude = []

    fetch( :ongr_exclude, [] ).each do |e|
      exclude << "--exclude=#{e}"
    end

    set :artifact_timestamp, now
    set :artifact_path, [fetch( :cache_path ), fetch( :artifact_timestamp )].join( "/" )

    run_locally do
      execute :mkdir, "-p", fetch( :artifact_path )
      execute :rsync, "-rlp", "--delete", "--delete-excluded", exclude.join( " " ), "./", fetch( :artifact_path )
    end

    rsync_plugin.get_redis_nm.hset fetch( :artifact_timestamp ), :pack, true
  end

end
