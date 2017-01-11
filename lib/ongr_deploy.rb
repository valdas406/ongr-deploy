require "ongr_deploy/aws"

set :stage_config_path,  "app/deploy"
set :deploy_config_path, "app/deploy.rb"

self.extend OngrDeploy::Aws
