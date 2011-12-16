# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :minitest

Hoe.spec 'gmail_contacts' do
  developer 'Eric Hodel', 'drbrain@segment7.net'

  self.rubyforge_name = 'seattlerb'
  self.testlib = :minitest

  dependency 'nokogiri', '~> 1.4'
  dependency 'net-http-persistent', ['~> 1.2', '> 1.2']
end

# vim: syntax=Ruby
