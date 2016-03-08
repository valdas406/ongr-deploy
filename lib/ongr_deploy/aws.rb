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

      ec2_client       = ::Aws::EC2::Client.new
      autoscale_client = ::Aws::AutoScaling::Client.new

      autoscale = ::Aws::AutoScaling::AutoScalingGroup.new name, autoscale_client

      autoscale.instances.each do |i|
        instance = ::Aws::EC2::Instance.new i.id, client: ec2_client

        server instance.private_ip_address, *args
      end
    end

  end

end
