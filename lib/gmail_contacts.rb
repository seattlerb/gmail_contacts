require 'rubygems'
require 'gdata'
require 'nokogiri'

##
# GmailContacts sits atop GData and turns the contact feed into
# GmailContacts::Contact objects for friendly consumption.
#
# GmailContacts was sponsored by AT&T Interactive.

class GmailContacts

  VERSION = '1'

  Contact = Struct.new :title, :emails, :ims, :phone_numbers, :addresses

  ##
  # Struct containing title, emails, ims, phone_numbers and addresses

  class Contact

    def pretty_print(q) # :nodoc:
      q.text "#{title}"
      q.breakable

      q.group 2 do
        q.breakable
        q.group 2, 'emails: ' do
          emails.each_with_index do |email, i|
            unless i == 0 then
              q.text ','
              q.breakable
            end

            email += " (Primary)" if i == 0
            q.text email
          end
        end

        q.breakable
        q.group 2, 'ims: ' do
          ims.each_with_index do |(address, type), i|
            unless i == 0 then
              q.text ','
              q.breakable
            end

            q.text "#{address} (#{type.sub(/.*#/, '')})"
          end
        end

        q.breakable
        q.group 2, 'phone numbers: ' do
          phone_numbers.each_with_index do |(number, type), i|
            unless i == 0 then
              q.text ','
              q.breakable
            end

            q.text "#{number} (#{type.sub(/.*#/, '')})"
          end
        end

        q.breakable
        addresses.each do |address, type|
          q.group 2, "#{type.sub(/.*#/, '')} address:\n" do
            address = address.split("\n").each do |line|
              q.text "#{' ' * q.indent}#{line}\n"
            end
          end
        end
      end
    end

    ##
    # Returns the user's primary email address

    def primary_email
      emails.first
    end

  end

  ##
  # Contact list author's email

  attr_reader :author_email

  ##
  # Contact list author's name

  attr_reader :author_name

  ##
  # GData::Client::Contacts object accessor for testing

  attr_accessor :contact_api # :nodoc:

  ##
  # Contact data
  #
  # An Array with contact title, primary email and alternate emails

  attr_reader :contacts

  ##
  # Contacts list identifier

  attr_reader :id

  ##
  # Contacts list title

  attr_reader :title

  ##
  # Creates a new GmailContacts using +authsub_token+.  If you don't yet have
  # an AuthSub token, call <tt>contact_api.auth_url</tt> providing your return
  # endpoint.
  #
  # See GData::Client::Base in the gdata gem and
  # http://code.google.com/apis/accounts/docs/AuthSub.html for more details.

  def initialize(authsub_token = nil)
    @authsub_token = authsub_token
    @session_token = false

    @id = nil
    @title = nil
    @author_email = nil
    @author_name = nil
    @contacts ||= []

    @contact_api = GData::Client::Contacts.new
  end

  ##
  # Fetches contacts from google for +email+.

  def fetch(email)
    get_token

    uri = "http://www.google.com/m8/feeds/contacts/#{email}/full"

    loop do
      res = @contact_api.get uri

      xml = Nokogiri::XML res.body

      parse xml

      next_uri = xml.xpath('//xmlns:feed/xmlns:link[@rel="next"]').first
      break unless next_uri

      uri = next_uri['href']
    end
  ensure
    revoke_token if token?
  end

  ##
  # Fetches an AuthSub session token

  def get_token
    @contact_api.authsub_token = @authsub_token
    @contact_api.auth_handler.upgrade
    @session_token = true
  end

  ##
  # Extracts contact information from +xml+, appending it to the current
  # contact information

  def parse(xml)
    @id    = xml.xpath('//xmlns:feed/xmlns:id').first.text
    @title = xml.xpath('//xmlns:feed/xmlns:title').first.text

    @author_email =
      xml.xpath('//xmlns:feed/xmlns:author/xmlns:email').first.text
    @author_name = xml.xpath('//xmlns:feed/xmlns:author/xmlns:name').first.text

    xml.xpath('//xmlns:feed/xmlns:entry').each do |entry|
      title = entry.xpath('.//xmlns:title').first.text
      emails = []
      emails << entry.xpath('.//gd:email[@primary]').first['address']
      alternates = entry.xpath('.//gd:email[not(@primary)]')

      emails.push(*alternates.map { |e| e['address'] })

      ims = []
      entry.xpath('.//gd:im').each do |im|
        ims << [im['address'], im['protocol']]
      end

      phones = []
      entry.xpath('.//gd:phoneNumber').each do |phone|
        phones << [phone.text, phone['rel']]
      end

      addresses = []
      entry.xpath('.//gd:postalAddress').each do |address|
        addresses << [address.text, address['rel']]
      end

      contact = Contact.new title, emails, ims, phones, addresses

      @contacts << contact
    end

    self
  end

  ##
  # Revokes our AuthSub token

  def revoke_token
    @contact_api.auth_handler.revoke
  end

  ##
  # Do we have an AuthSub session token?

  def token?
    @session_token
  end

end

