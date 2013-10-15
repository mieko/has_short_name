lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'has_short_name/version'

Gem::Specification.new do |spec|
  spec.name          = "has_short_name"
  spec.version       = HasShortName::VERSION
  spec.authors       = ["Mike Owens"]
  spec.email         = ["mike@filespanker.com"]
  spec.description   = "ActiveRecord extension that generates abbreviated short names from names"
  spec.summary       = "Generate abbreviated names from full names"
  spec.homepage      = "https://github.com/mieko/has_short_name"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
