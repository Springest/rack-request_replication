# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack/request_replication/version'

Gem::Specification.new do |spec|
  spec.name          = 'rack-request_replication'
  spec.version       = Rack::RequestReplication::VERSION
  spec.authors       = ['Wouter de Vos', 'Mark Mulder']
  spec.email         = ['wouter@springest.com']
  spec.summary       = %q{Request replication MiddleWare for Rack.}
  spec.description   = %q{Replicate or record HTTP requests to your Rack application and replay them elsewhere or at another time.}
  spec.homepage      = 'https://github.com/Springest/rack-request_replication'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',   '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rack-test', '>= 0.5.3'
  spec.add_development_dependency 'rspec',     '~> 3.0'
  spec.add_development_dependency 'yard' ,     '>= 0.5.5'
  spec.add_development_dependency 'sinatra'
  spec.add_development_dependency 'sinatra-contrib'

  spec.add_runtime_dependency 'rack', '>= 1.0.0'
  spec.add_runtime_dependency 'redis', '>= 1.0.0'
  spec.add_runtime_dependency 'activesupport', '>= 2.1.0'
end
