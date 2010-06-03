require 'cgi'
require 'net/http/persistent'
require 'nokogiri'

##
# GmailContacts sits atop GData and turns the contact feed into
# GmailContacts::Contact objects for friendly consumption.
#
# See sample/authsub.rb for an example which uses GmailContacts.
#
# GmailContacts was sponsored by AT&T Interactive.
#
# == Upgrading from 1.x
#
# gmail_contacts no longer depends on gdata and performs its own AuthSub
# handling.  Use GmailContacts#authsub_url instead of #authsub_url on
# #contact_api.
#
# gmail_contacts no longer uses gdata to raise exceptions and instead raise
# Net::HTTPServerException instead.  Rescue Net::HTTPServerException instead
# of GData::Client::RequestError.  Net::HTTPServerException responds to
# #response which you can use to determine what kind of error you got:
#
#   begin
#     gc.fetch 'nobody@example', false
#   rescue Net::HTTPServerException => e
#     case e.response
#     when Net::HTTPForbidden then
#       puts "You are not allowed to view contacts for this user"
#     end
#   end

class GmailContacts

  VERSION = '2.0'

  class Error < RuntimeError; end

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
  # The current authsub token.  If you upgrade a request token to a session
  # token the value will change.

  attr_reader :authsub_token

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
  # an AuthSub token, call #authsub_url.

  def initialize(authsub_token = nil, session_token = false)
    @authsub_token = authsub_token
    @session_token = session_token

    @id = nil
    @title = nil
    @author_email = nil
    @author_name = nil
    @contacts ||= []

    @google = URI.parse 'https://www.google.com'
    @http = Net::HTTP::Persistent.new "gmail_contacts_#{object_id}"
    @http.debug_output = $stderr
    @http.headers['Authorization'] = "AuthSub token=\"#{@authsub_token}\""
  end

  ##
  # Returns a URL that will allow a user to authorize contact retrieval.
  # Redirect the user to this URL and they will (should) approve your contact
  # retrieval request.
  #
  # +next_url+ is where Google will redirect the user after they grant your
  # request.
  #
  # See http://code.google.com/apis/accounts/docs/AuthSub.html for more
  # details.

  def authsub_url next_url, secure = false, session = true, domain = nil
    query = {
      'next'    => CGI.escape(next_url),
      'scope'   => 'http%3A%2F%2Fwww.google.com%2Fm8%2Ffeeds%2F',
      'secure'  => (secure  ? 1 : 0),
      'session' => (session ? 1 : 0),
    }

    query['hd'] = CGI.escape domain if domain

    query = query.map do |key, value|
      "#{key}=#{value}"
    end.sort.join '&'

    "https://www.google.com/accounts/AuthSubRequest?#{query}"
  end

  ##
  # Fetches contacts from google for +email+.

  def fetch(email, revoke = true)
    get_token

    uri = URI.parse "http://www.google.com/m8/feeds/contacts/#{email}/full"

    loop do
      res = request uri

      xml = Nokogiri::XML res.body

      parse xml

      next_uri = xml.xpath('//xmlns:feed/xmlns:link[@rel="next"]').first
      break unless next_uri

      uri += next_uri['href']
    end

    yield if block_given?
  ensure
    revoke_token if revoke and token?
  end

  ##
  # Fetches the photo data for +contact+ which may be a photo URL

  def fetch_photo(contact)
    photo_url = if String === contact then
                  contact
                else
                  contact.photo_url
                end
    response = request URI.parse photo_url

    response.body
  end

  ##
  # Fetches an AuthSub session token.  Changes the value of #authsub_token so
  # you can store it in a database or wherever.

  def get_token
    return if @session_token

    response = request @google + '/accounts/AuthSubSessionToken'

    response.body =~ /^Token=(.*)/

    @authsub_token = $1
    @http.headers['Authorization'] = "AuthSub token=\"#{@authsub_token}\""
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
  # Performs a GET for +uri+ and returns the Net::HTTPResponse.  Raises
  # Net::HTTPError if the response wasn't a success (OK, Created, Found).

  def request uri
    response = @http.request uri

    case response
    when Net::HTTPOK, Net::HTTPCreated, Net::HTTPFound then
      response
    else
      response.error!
    end
  end

  ##
  # Revokes our AuthSub session token

  def revoke_token
    request @google + '/accounts/AuthSubRevokeToken'

    @session_token = false
  end

  ##
  # Do we have an AuthSub session token?

  def token?
    @session_token
  end

end

