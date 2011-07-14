# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rufus-mnemo}
  s.version = "1.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mettraux"]
  s.date = %q{2010-11-21}
  s.description = %q{
Turning (large) integers into japanese sounding words and vice versa'
  }
  s.email = %q{jmettraux@gmail.com}
  s.extra_rdoc_files = ["LICENSE.txt", "README.txt"]
  s.files = ["CHANGELOG.txt", "CREDITS.txt", "LICENSE.txt", "README.txt", "Rakefile", "doc/rdoc-style.css", "lib/rufus-mnemo.rb", "lib/rufus/mnemo.rb", "rufus-mnemo.gemspec", "test/test.rb"]
  s.homepage = %q{http://github.com/jmettraux/rufus-mnemo/}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rufus}
  s.rubygems_version = %q{1.4.2}
  s.summary = %q{Turning (large) integers into japanese sounding words and vice versa}
  s.test_files = ["test/test.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<jeweler>, [">= 0"])
    else
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<jeweler>, [">= 0"])
    end
  else
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<jeweler>, [">= 0"])
  end
end