# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/gmail_contacts.rb'

Hoe.new('gmail_contacts', GmailContacts::VERSION) do |p|
  p.rubyforge_name = 'seattlerb' # if different than lowercase project name
  p.developer 'Eric Hodel', 'drbrain@segment7.net'

  p.testlib = :minitest

  p.extra_deps << ['gdata', '~> 1.1']
  p.extra_deps << ['nokogiri', '~> 1.2']
  p.extra_dev_deps << ['minitest', '~> 1.3']
end

# vim: syntax=Ruby
