# frozen_string_literal: true

require_relative "lib/manymessage/version"

Gem::Specification.new do |spec|
  spec.name = "manymessage"
  spec.version = Manymessage::VERSION
  spec.authors = ["jltml"]
  spec.email = ["8261330+jltml@users.noreply.github.com"]

  spec.summary = "Send mass texts super easily!"
  # spec.description = "TODO: Write a longer description or delete this line."
  spec.homepage = "https://github.com/jltml/manymessage"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "json", "~> 2.6"
  spec.add_dependency "imessage", "~> 0.4.0"
  spec.add_dependency "paint", "~> 2.2"
  spec.add_dependency "ptools", "~> 1.4"
  spec.add_dependency "os", "~> 1.1"
  spec.add_dependency "phony", "~> 2.19"
  spec.add_dependency "shellwords", "~> 0.1.0"
  spec.add_dependency "tty-progressbar", "~> 0.18.2"
  spec.add_dependency "tty-prompt", "~> 0.23.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
