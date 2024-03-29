# config valid only for current version of Capistrano
lock "<%= Capistrano::VERSION %>"

set :application, "my_app_name"
set :repo_url, "git@example.com:me/my_repo.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, "app/config/parameters.yml"

# Default value for linked_dirs is []
append :linked_dirs, "app/logs"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

## AWS Credentials

# set :aws_region, "xxx"
# set :aws_id, "xxx"
# set :aws_secret, "xxx"
# set :aws_role_arn, "xxx"

## Redis Connection

# set :redis_host, "localhost"
# set :redis_port, 6379
# set :redis_db, 0

## ONGR Extensions

# set :ongr_create_params, false
# set :ongr_exclude, []
# set :ongr_warmup, []
