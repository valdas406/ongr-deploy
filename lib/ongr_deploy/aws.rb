require "aws-sdk"

module OngrDeploy

  module Aws

    def autoscale( name, *args )
      ::Aws.config.update(
        {
          region:      fetch( :aws_region ),
          credentials: ::Aws::Credentials.new( fetch( :aws_id ), fetch( :aws_secret ) )
        }
      )

      autoscale = ::Aws::AutoScaling::AutoScalingGroup.new name, autoscale_client

      autoscale.instances.each do |i|
        next if i.lifecycle_state != "InService" || i.health_status != "Healthy"

        instance = ::Aws::EC2::Instance.new i.id

        server instance.private_ip_address, *args
      end
    end

  end

end
