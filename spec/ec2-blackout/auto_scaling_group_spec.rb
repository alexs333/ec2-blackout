module Ec2::Blackout
  describe AutoScalingGroup do

    describe ".groups" do

      it "returns all groups in the region" do
        auto_scaling_stub = double("autoscaling")
        expect(auto_scaling_stub).to receive(:groups).and_return([double, double])
        expect(AWS::AutoScaling).to receive(:new).with(:region => "ap-southeast-2").and_return(auto_scaling_stub)
        groups = AutoScalingGroup.groups("ap-southeast-2", Options.new)
        expect(groups.size).to eq 2
      end

    end


    describe "#stop" do
      let!(:aws_group) { double("autoscaling group") }
      let!(:group) { stubbed_stoppable_auto_scaling_group(aws_group) }

      it "sets desired capacity to zero" do
        expect(aws_group).to receive(:set_desired_capacity).with(0)
        group.stop
      end

      it "tags the instance with timestamp and original desired capacity" do
        allow(aws_group).to receive(:desired_capacity).and_return(3)

				expect(aws_group).to receive(:update).with(satisfy { |attributes| expect_ec2_blackout_tags(attributes[:tags], Time.now, 3) })

        group.stop
      end

    end


    describe "#start" do
      let!(:aws_group) { double("autoscaling group") }
      let!(:group) { stubbed_startable_auto_scaling_group(aws_group) }

      it "restores desired capacity to its previous setting" do
        expect(aws_group).to receive(:tags).and_return(ec2_blackout_tags("2014-02-10 11:44:58 UTC", 3))
        expect(aws_group).to receive(:set_desired_capacity).with(3)
        group.start
      end

      it "removes the ec2 blackout tags from the autoscaling group" do
        tags = ec2_blackout_tags("2014-02-10 12s:44:58 UTC", 2)
        allow(aws_group).to receive(:tags).and_return(tags)
        expect(aws_group).to receive(:delete_tags).with(tags)
        group.start
      end

      it "sets desired capacity to min capacity if there is no desired capacity tag" do
        tags = ec2_blackout_tags("2014-02-10 11:44:58 UTC", nil)
        allow(aws_group).to receive(:tags).and_return(tags)
        allow(aws_group).to receive(:min_size).and_return(4)
        expect(aws_group).to receive(:set_desired_capacity).with(4)
        group.start
      end

    end


    describe("#stoppable?") do

      let!(:aws_group) { double("autoscaling group") }
      let!(:group) { stubbed_stoppable_auto_scaling_group(aws_group) }

      it "returns true if the group meets all the stoppable conditions" do
        stoppable, reason = group.stoppable?
        expect(stoppable).to be true
      end

      it "returns false if the tags match the exclude tag options" do
        options = Ec2::Blackout::Options.new(:exclude_by_tag =>  ["foo=bar"])
        group = stubbed_stoppable_auto_scaling_group(aws_group, options)
        allow(aws_group).to receive(:tags).and_return(asg_tags("foo" => "bar"))

        stoppable, reason = group.stoppable?
        expect(stoppable).to be false
      end

      it "returns false if the tags do not match the include tag options" do
        options = Ec2::Blackout::Options.new(:include_by_tag =>  ["foo=bar"])
        group = stubbed_stoppable_auto_scaling_group(aws_group, options)
        allow(aws_group).to receive(:tags).and_return(asg_tags("foo" => "baz"))

        stoppable, reason = group.stoppable?
        expect(stoppable).to be false
      end

      it "returns false if the desired capacity is zero" do
        allow(aws_group).to receive(:desired_capacity).and_return(0)
        stoppable, reason = group.stoppable?
        expect(stoppable).to be false
      end

      it "returns false if min size is greater than zero" do
        allow(aws_group).to receive(:min_size).and_return(1)
        stoppable, reason = group.stoppable?
        expect(stoppable).to be false
      end

      it "treats the name of the ASG as a tag with key 'Name'" do
        options = Ec2::Blackout::Options.new(:include_by_tag =>  ["Name=My ASG"])
        group = stubbed_stoppable_auto_scaling_group(aws_group, options)
        allow(aws_group).to receive(:name).and_return("My ASG")

        stoppable, reason = group.stoppable?
        expect(stoppable).to be true
      end

    end


    describe("#startable?") do

      let!(:aws_group) { double("autoscaling group") }
      let!(:group) { stubbed_startable_auto_scaling_group(aws_group) }

      it "returns true if the instance was previously stopped with ec2 blackout" do
        startable, reason = group.startable?
        expect(startable).to be true
      end

      it "returns false if there is no ec2 blackout timestamp tag" do
        allow(aws_group).to receive(:tags).and_return([])
        startable, reason = group.startable?
        expect(startable).to be false
      end

      it "returns true if the force option was specified, even if there is no ec2 blackout timestamp tag" do
        options = Ec2::Blackout::Options.new(:force => true)
        aws_group = double("autoscaling group")
        group = stubbed_startable_auto_scaling_group(aws_group, options)
        allow(aws_group).to receive(:tags).and_return([])
        startable, reason = group.startable?
        expect(startable).to be true
      end

      it "returns false if max size is zero" do
        allow(aws_group).to receive(:max_size).and_return(0)
        startable, reason = group.startable?
        expect(startable).to be false
      end

    end

    def stubbed_stoppable_auto_scaling_group(underlying_aws_stub, options = Options.new)
      allow(underlying_aws_stub).to receive(:name).and_return("Test AutoScaling Group")
      allow(underlying_aws_stub).to receive(:desired_capacity).and_return(1)
      allow(underlying_aws_stub).to receive(:min_size).and_return(0)
      allow(underlying_aws_stub).to receive(:tags).and_return([])
      allow(underlying_aws_stub).to receive(:update)
      allow(underlying_aws_stub).to receive(:set_desired_capacity)
      AutoScalingGroup.new(underlying_aws_stub, options)
    end

    def stubbed_startable_auto_scaling_group(underlying_aws_stub, options = Options.new)
      allow(underlying_aws_stub).to receive(:name).and_return("Test AutoScaling Group")
      allow(underlying_aws_stub).to receive(:tags).and_return(ec2_blackout_tags("2014-02-10 11:44:58 UTC", 1))
      allow(underlying_aws_stub).to receive(:max_size).and_return(10)
      allow(underlying_aws_stub).to receive(:delete_tags)
      allow(underlying_aws_stub).to receive(:set_desired_capacity)
      AutoScalingGroup.new(underlying_aws_stub, options)
    end

    def ec2_blackout_tags(timestamp, desired_capacity)
      tags = asg_tags(AutoScalingGroup::TIMESTAMP_TAG_NAME => timestamp)
      if desired_capacity
        tags += asg_tags(AutoScalingGroup::DESIRED_CAPACITY_TAG_NAME => desired_capacity.to_s)
      end
      tags
    end

    def asg_tags(tags_hash)
      tags_hash.map {|k,v| {key: k, value: v, propagate_at_launch: false} }
    end

    def expect_ec2_blackout_tags(tags, timestamp, desired_capacity)
      timestamp_tag = tags.find { |tag| tag[:key] == AutoScalingGroup::TIMESTAMP_TAG_NAME }
      expect(Date.parse(timestamp_tag[:value]).to_time - timestamp).to be < 1
      expect(timestamp_tag[:propagate_at_launch]).to be false

      desired_capacity_tag = tags.find { |tag| tag[:key] == AutoScalingGroup::DESIRED_CAPACITY_TAG_NAME }
      expect(desired_capacity_tag[:value]).to eq desired_capacity.to_s
      expect(desired_capacity_tag[:propagate_at_launch]).to be false
    end

  end
end
