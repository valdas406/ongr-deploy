require "yaml"
require "digest"
require "deep_merge"

rsync_plugin = self
tmp_dir = ENV['TMP_DIR'] || '/tmp'

@content = {}

namespace :rsync do

  # Extensions

  task :init do
    set :cache_namespace, [fetch(:application), fetch( :stage )].join( "_" )
    set :cache_path, [tmp_dir, fetch( :cache_namespace )].join( "/" )

    artifact_db = rsync_plugin.get_redis_nm.keys "*"

    fail "ARTIFACT DB IS EMPTY" if artifact_db.empty?

    artifact_db.map! { |i| i.to_i }
    artifact_db.sort!

    run_locally do
      artifact_db.each do |i|
        test_path   = [fetch( :cache_path ), i].join( "/" )
        test_result = test( "[ -d #{test_path} ]" ) ? "OK" : "MISSING"

        puts "CHECKING DB -> ARTIFACT MAPPING #{i} - #{test_result}"

        exit 1 unless test_result == "OK"
      end
    end

    if fetch( :deploying, false )
      autoscale = ENV["AUTOSCALE"]

      if autoscale == "true"
        artifact_db.keep_if { |i| rsync_plugin.get_redis_nm.hget( i, :deploy ) == "true" }

        set :artifact_timestamp, artifact_db.pop.to_s
        set :artifact_history, artifact_db
      else
        set :artifact_timestamp, artifact_db.pop.to_s
        set :artifact_history, artifact_db.keep_if { |i| rsync_plugin.get_redis_nm.hget( i, :deploy ) == "true" }
      end
    else
      artifact_db.keep_if { |i| rsync_plugin.get_redis_nm.hget( i, :deploy ) == "true" }

      fail "MIN RELEASE COUNT IS 2 FOR ROLLBACK" if artifact_db.size < 2

      set :artifact_timestamp, artifact_db[-2].to_s
      set :delete_timestamp, artifact_db[-1].to_s
    end

    set :artifact_path, [fetch( :cache_path ), fetch( :artifact_timestamp )].join( "/" )
  end

  task check: :init do
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
        key  = Digest::MD5.hexdigest fqdn

        merge_log = "MERGING parameters.yml for #{fqdn}[#{key}]: "

        Dir.chdir fetch( :artifact_path ) do
          ["parameters.yml.#{fetch :stage}", "parameters.yml.#{fetch :stage}.#{fqdn}"].each do |yml|
            if File.exists? "app/config/#{yml}"
              override = YAML::load File.read "app/config/#{yml}"

              merge_log << "#{yml}, "

              unless override
                fail "SYNTAX ERROR ON YML FILE #{yml}"
              end

              params.deep_merge! override
            end
          end
        end

        @content[key] = StringIO.new params.to_yaml

        within shared_path do
          if test "[ -f #{shared_path}/app/config/parameters.yml ]"
            execute :cp, "app/config/parameters.yml", "app/config/parameters-#{Time.new.strftime "%Y%m%d%H%M"}.yml"
          end

          merge_log << "\nuploading for #{fqdn}[#{key}]"

          upload! @content[key], "#{shared_path}/app/config/parameters.yml"
          execute :chmod, "664", "app/config/parameters.yml"
        end

        puts merge_log
      end
    end
  end

  task :sync_history do
    on release_roles( :all ) do |host|
      fetch( :artifact_history, [] ).each do |i|
        local_path  = [fetch( :cache_path ), i].join "/"
        remote_path = [releases_path, i].join "/"

        next if test "[ -d #{remote_path} ]"

        run_locally do
          execute :rsync, "-crlz", "--stats", "#{local_path}/", "#{host.username}@#{host.hostname}:#{remote_path}"
        end

        execute :chmod, "-R", "g+w", remote_path
      end
    end
  end

  task :sync_current do
    on release_roles( :all ) do |host|
      run_locally do
        execute :rsync, "-crlz", "--delete", "--stats", "#{fetch :artifact_path}/", "#{host.username}@#{host.hostname}:#{repo_path}"
      end
    end
  end

  task create_release: [:sync_history, :sync_current] do
    set_release_path fetch( :artifact_timestamp )

    on release_roles( :all ) do
      next if test "[ -d #{release_path} ]"

      execute :mkdir, "-p", release_path
      rsync_plugin.release
      execute :chmod, "-R", "g+w", release_path
    end
  end

  task :set_current_revision do
    on release_roles( :all ) do
      within repo_path do
        set :current_revision, rsync_plugin.fetch_revision
      end
    end
  end

  task :warmup_release do
    on release_roles( :all ) do
      within release_path do
        fetch( :ongr_warmup, [] ).each do |i|
          next if test "[ -d #{release_path}/app/cache/#{i} ]"
          execute "app/console", "cache:warmup", "-e", i
        end
      end
    end
  end

  task :published do
    rsync_plugin.get_redis.set fetch( :cache_namespace ), fetch( :artifact_timestamp )

    if fetch( :deploying, false )
      rsync_plugin.get_redis_nm.hset fetch( :artifact_timestamp ), :deploy, true

      artifact_db = rsync_plugin.get_redis_nm.keys "*"
      artifact_db.map! { |i| i.to_i }
      artifact_db.sort!
      artifact_db.keep_if { |i| rsync_plugin.get_redis_nm.hget( i, :deploy ) == "true" }

      fetch( :keep_releases ).times { artifact_db.pop }

      artifact_db.each do |i|
        rsync_plugin.get_redis_nm.del i
      end
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
    set :cache_path, [tmp_dir, fetch( :cache_namespace )].join( "/" )
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

      if any? :linked_dirs
        execute :mkdir, "-p", linked_dir_parents( Pathname.new( fetch :artifact_path ) )

        fetch( :linked_dirs ).each do |dir|
          target = Pathname.new( fetch :artifact_path ).join dir
          source = shared_path.join dir

          execute :rm, "-rf", target if test "[ -d #{target} ]"
          execute :ln, "-s", source, target
        end
      end

      if any? :linked_files
        execute :mkdir, "-p", linked_file_dirs( Pathname.new( fetch :artifact_path ) )

        fetch( :linked_files ).each do |file|
          target = Pathname.new( fetch :artifact_path ).join file
          source = shared_path.join file

          execute :rm, target if test "[ -f #{target} ]"
          execute :ln, "-s", source, target
        end
      end
    end

    rsync_plugin.get_redis_nm.hset fetch( :artifact_timestamp ), :pack, true

    run_locally do
      artifact_db   = rsync_plugin.get_redis_nm.keys "*"
      artifact_disk = capture(:ls, fetch( :cache_path ) ).split

      artifact_disk.each do |disk|
        execute :rm, "-rf", [fetch( :cache_path ), disk].join( "/" ) unless artifact_db.include?( disk )
      end

      artifact_db.delete_if { |i| rsync_plugin.get_redis_nm.hget( i, :deploy ) == "true" }
      artifact_db.map! { |i| i.to_i }
      artifact_db.sort!

      3.times { artifact_db.pop }

      artifact_db.each do |i|
        rsync_plugin.get_redis_nm.del i
        execute :rm, "-rf", [fetch( :cache_path ), i].join( "/" )
      end
    end
  end

end
