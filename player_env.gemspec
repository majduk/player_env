Gem::Specification.new do |s|
  s.name        = "player_env"
  s.version     = "0.3"
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Player Env"
  s.email       = ""
  s.homepage    = "http://www.play.pl"
  s.description = "Player Env"
  s.authors     = ['Michal Ajduk']

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency("serviceproxy")
  s.add_dependency("hpricot")
end
