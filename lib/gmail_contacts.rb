require 'rubygems'
require 'gdata'
require 'nokogiri'

##
# GmailContacts sits atop GData and turns the contact feed into
# GmailContacts::Contact objects for friendly consumption.
#
# GmailContacts was sponsored by AT&T Interactive.

class GmailContacts

  VERSION = '1.3'

  Contact = Struct.new :title, :emails, :ims, :phone_numbers, :addresses,
                       :photo_url

  ##
  # Struct containing title, emails, ims, phone_numbers and addresses

  class Contact

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

  def initialize(authsub_token = nil, session_token = false)
    @authsub_token = authsub_token
    @session_token = session_token

    @id = nil
    @title = nil
    @author_email = nil
    @author_name = nil
    @contacts ||= []

    @contact_api = GData::Client::Contacts.new
  end

  ##
  # Fetches contacts from google for +email+.

  def fetch(email, revoke = true)
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

    yield if block_given?
  ensure
    revoke_token if revoke and token?
  end

  ##
  # Fetches the photo data for +contact+

  def fetch_photo(contact)
    res = @contact_api.get contact.photo_url

    res.body
  end

  ##
  # Fetches an AuthSub session token

  def get_token
    return if @session_token
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
      primary = entry.xpath('.//gd:email[@primary]')
      next unless primary.first
      emails << primary.first['address']
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

      photo_link = entry.xpath('.//xmlns:link[@rel="http://schemas.google.com/contacts/2008/rel#photo"]').first
      photo_url = photo_link['href'] if photo_link

      contact = Contact.new title, emails, ims, phones, addresses, photo_url

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

