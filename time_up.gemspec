require_relative "lib/time_up/version"

Gem::Specification.new do |spec|
  spec.name = "time_up"
  spec.version = TimeUp::VERSION
  spec.authors = ["Justin Searls"]
  spec.email = ["searls@gmail.com"]

  spec.summary = "A little library for managing multiple named timers"
  spec.homepage = "https://github.com/testdouble/time_up"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/testdouble/time_up"
  spec.metadata["changelog_uri"] = "https://github.com/testdouble/time_up/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
