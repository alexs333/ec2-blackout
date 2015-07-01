# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ec2-blackout/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Stephen Bartlett", "Charles Blaxland"]
  gem.email         = ["stephenb@rtlett.org"]
  gem.description   = Ec2::Blackout.description
  gem.summary       = Ec2::Blackout.summary
  gem.homepage      = "https://github.com/srbartlett/ec2-blackout"

	gem.add_dependency 'commander'
  gem.add_dependency 'aws-sdk', '~> 1.64'
  gem.add_dependency 'colorize'

	gem.add_development_dependency 'rspec', '~> 3.3'
	gem.add_development_dependency 'byebug'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ec2-blackout"
  gem.require_paths = ["lib"]
  gem.version       = Ec2::Blackout::VERSION
end
