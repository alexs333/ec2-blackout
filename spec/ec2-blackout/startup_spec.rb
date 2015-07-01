describe Ec2::Blackout::Startup do

  describe "#execute" do

    it "should start up only startable resources" do
      startable_group = startable_resource(Ec2::Blackout::AutoScalingGroup)
      expect(startable_group).to receive(:start)

      unstartable_group = unstartable_resource(Ec2::Blackout::AutoScalingGroup)
      expect(unstartable_group).not_to receive(:start)

      startable_instance = startable_resource(Ec2::Blackout::Ec2Instance)
      expect(startable_instance).to receive(:start)

      unstartable_instance = unstartable_resource(Ec2::Blackout::Ec2Instance)
      expect(unstartable_instance).not_to receive(:start)

      groups = [startable_group, unstartable_group]
      instances = [startable_instance, unstartable_instance]

      allow(Ec2::Blackout::AutoScalingGroup).to receive(:groups).and_return(groups)
      allow(Ec2::Blackout::Ec2Instance).to receive(:stopped_instances).and_return(instances)

      startup = Ec2::Blackout::Startup.new(double, Ec2::Blackout::Options.new(:regions => ["ap-southeast-2"]))
      startup.execute
    end

    it "should start up instances in all regions given by the options" do
      options = Ec2::Blackout::Options.new(:regions => ["ap-southeast-1", "ap-southeast-2"])

      expect(Ec2::Blackout::AutoScalingGroup).to receive(:groups).with("ap-southeast-1", anything).and_return([])
      expect(Ec2::Blackout::AutoScalingGroup).to receive(:groups).with("ap-southeast-2", anything).and_return([])
      expect(Ec2::Blackout::Ec2Instance).to receive(:stopped_instances).with("ap-southeast-1", anything).and_return([])
      expect(Ec2::Blackout::Ec2Instance).to receive(:stopped_instances).with("ap-southeast-2", anything).and_return([])

      startup = Ec2::Blackout::Startup.new(double, options)
      startup.execute
    end

    it "should not start instances if the dry run option has been specified" do
      options = Ec2::Blackout::Options.new(:dry_run => true, :regions => ["ap-southeast-2"])
      startable_group = startable_resource(Ec2::Blackout::AutoScalingGroup)
      expect(startable_group).not_to receive(:start)

      startable_instance = startable_resource(Ec2::Blackout::Ec2Instance)
      expect(startable_instance).not_to receive(:start)

      allow(Ec2::Blackout::AutoScalingGroup).to receive(:groups).and_return([startable_group])
      allow(Ec2::Blackout::Ec2Instance).to receive(:stopped_instances).and_return([startable_instance])

      startup = Ec2::Blackout::Startup.new(double, options)
      startup.execute
    end

  end


  def startable_resource(type)
    resource(type, true)
  end

  def unstartable_resource(type)
    resource(type, false)
  end

  def resource(type, startable)
    resource = double(type)
    expect(resource).to receive(:startable?).and_return(startable)
    resource
  end

end
