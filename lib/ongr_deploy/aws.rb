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

      pending = []
      running = []

      10.times do
        autoscale = ::Aws::AutoScaling::AutoScalingGroup.new name

        pending = []
        running = []

        autoscale.instances.each do |i|
          pending << i if i.lifecycle_state == "Pending"
          running << i if i.lifecycle_state == "InService" || i.health_status == "Healthy"
        end

        break if pending.size.zero?

        puts "waiting for pending servers #{pending.size}, running #{running.size}"

        sleep 2
      end

      running.each do |r|
        instance = ::Aws::EC2::Instance.new r.id
        server instance.private_ip_address, *args
      end
    end

  end

end
