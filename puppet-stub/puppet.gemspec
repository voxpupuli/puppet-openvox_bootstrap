# An empty gem called puppet, so the “real” one is not loaded as a dependency
# Otherwise we'd have Puppet twice in our dependencies, which confuses Bundler and leads to error like:
#
# > The `puppet` executable in the `openvox` gem is being loaded, but it's also present in other gems (puppet).
# > If you meant to run the executable for another gem, make sure you use a project specific binstub (`bundle binstub <gem_name>`).

Gem::Specification.new do |spec|
  spec.name = "puppet"
  # The latest puppet gem on rubygems.org is 8.10.0
  spec.version = "8.17.0"
  spec.summary = "Stub"
  spec.authors = ["nobody"]
  spec.add_runtime_dependency('openvox')
end
