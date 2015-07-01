describe Ec2::Blackout::Shutdown do

  describe "#execute" do

    it "should shut down only stoppable resources" do
      stoppable_group = stoppable_resource(Ec2::Blackout::AutoScalingGroup)
      expect(stoppable_group).to receive(:stop)

      unstoppable_group = unstoppable_resource(Ec2::Blackout::AutoScalingGroup)
      expect(unstoppable_group).not_to receive(:stop)

      stoppable_instance = stoppable_resource(Ec2::Blackout::Ec2Instance)
      expect(stoppable_instance).to receive(:stop)

      unstoppable_instance = unstoppable_resource(Ec2::Blackout::Ec2Instance)
      expect(unstoppable_instance).not_to receive(:stop)

      groups = [stoppable_group, unstoppable_group]
      instances = [stoppable_instance, unstoppable_instance]

      allow(Ec2::Blackout::AutoScalingGroup).to receive(:groups).and_return(groups)
      allow(Ec2::Blackout::Ec2Instance).to receive(:running_instances).and_return(instances)

      shutdown = Ec2::Blackout::Shutdown.new(double, Ec2::Blackout::Options.new(:regions => ["ap-southeast-2"]))
      shutdown.execute
    end

    it "should shut down instances in all regions given by the options" do
      options = Ec2::Blackout::Options.new(:regions => ["ap-southeast-1", "ap-southeast-2"])

      expect(Ec2::Blackout::AutoScalingGroup).to receive(:groups).with("ap-southeast-1", anything).and_return([])
      expect(Ec2::Blackout::AutoScalingGroup).to receive(:groups).with("ap-southeast-2", anything).and_return([])
      expect(Ec2::Blackout::Ec2Instance).to receive(:running_instances).with("ap-southeast-1", anything).and_return([])
      expect(Ec2::Blackout::Ec2Instance).to receive(:running_instances).with("ap-southeast-2", anything).and_return([])

      shutdown = Ec2::Blackout::Shutdown.new(double, options)
      shutdown.execute
    end

    it "should not stop instances if the dry run option has been specified" do
      options = Ec2::Blackout::Options.new(:dry_run => true, :regions => ["ap-southeast-2"])
      stoppable_group = stoppable_resource(Ec2::Blackout::AutoScalingGroup)
      expect(stoppable_group).not_to receive(:stop)

      stoppable_instance = stoppable_resource(Ec2::Blackout::Ec2Instance)
      expect(stoppable_instance).not_to receive(:stop)

      allow(Ec2::Blackout::AutoScalingGroup).to receive(:groups).and_return([stoppable_group])
      allow(Ec2::Blackout::Ec2Instance).to receive(:running_instances).and_return([stoppable_instance])

      shutdown = Ec2::Blackout::Shutdown.new(double, options)
      shutdown.execute
    end

  end


  def stoppable_resource(type)
    resource(type, true)
  end

  def unstoppable_resource(type)
    resource(type, false)
  end

  def resource(type, stoppable)
    resource = double(type)
    expect(resource).to receive(:stoppable?).and_return(stoppable)
    resource
  end

end
