# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb

Hoe.spec 'gmail_contacts' do
  developer 'Eric Hodel', 'drbrain@segment7.net'

  self.rubyforge_name = 'seattlerb'
  self.testlib = :minitest

  extra_deps << ['gdata', '~> 1.1']
  extra_deps << ['nokogiri', '~> 1.2']
  extra_dev_deps << ['minitest', '~> 1.3']
end

# vim: syntax=Ruby
