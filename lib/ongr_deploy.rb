require "ongr_deploy/core"
require "ongr_deploy/aws"

self.extend OngrDeploy::Core
self.extend OngrDeploy::Aws

ongr_setup
