require 'ec2-blackout'
require 'byebug'

# Make sure we don't accidentally hit a real AWS service
AWS.stub!
