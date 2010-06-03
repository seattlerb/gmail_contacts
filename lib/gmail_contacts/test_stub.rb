require 'gmail_contacts'

##
# Handy data files and GData modifications that allow GmailContacts to be
# more easily tested
#
# To setup:
#
#   require 'gmail_contacts'
#   require 'gmail_contacts/test_stub'
#
#   class TestMyClass < Test::Unit::TestCase
#     def test_something
#       GmailContacts.stub
#
#       # ... your code using gc
#
#     end
#   end
#
# If you set the authsub token to 'recycled_authsub_token', the test stub will
# raise a GData::Client::AuthorizationError when you call #get_token.
#
# If you set the authsub token to 'wrong_user_authsub_token', the test stub
# will raise a GData::Client::AuthorizationError when you call #fetch.
#
# If you set the authsub token to 'authsub_token', #get_token will change it
# to 'authsub_token-upgraded' to indicate it was upgraded to a session token.
#
# If you fetch a photo with 404 in the url, #fetch_photo will raise a
# Net::HTTPServerException with a 404 response inside.
#
# #revoke_token will set the token to 'authsub_token-revoked' to indicate it
# was revoked.

class GmailContacts::TestStub

  ##
  # First page of contacts

  CONTACTS = <<-ATOM
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearch/1.1/" xmlns:gContact="http://schemas.google.com/contact/2008" xmlns:batch="http://schemas.google.com/gdata/batch" xmlns:gd="http://schemas.google.com/g/2005" gd:etag="W/&quot;CEMBRHY6fSp7ImA9WxVUGEk.&quot;">
  <id>eric@example.com</id>
  <updated>2009-03-23T21:07:35.815Z</updated>
  <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
  <title>drbrain's Contacts</title>
  <link rel="alternate" type="text/html" href="http://www.google.com/"/>
  <link rel="http://schemas.google.com/g/2005#feed" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full"/>
  <link rel="http://schemas.google.com/g/2005#post" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full"/>
  <link rel="http://schemas.google.com/g/2005#batch" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/batch"/>
  <link rel="self" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full?max-results=2"/>
  <link rel="next" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=3&amp;max-results=2"/>
  <author>
    <name>drbrain</name>
    <email>eric@example.com</email>
  </author>
  <generator version="1.0" uri="http://www.google.com/m8/feeds">Contacts</generator>
  <openSearch:totalResults>4</openSearch:totalResults>
  <openSearch:startIndex>1</openSearch:startIndex>
  <openSearch:itemsPerPage>2</openSearch:itemsPerPage>
  <entry gd:etag="&quot;SHg-cTVSLip7ImA9WB5WGUUIQgc.&quot;">
    <id>http://www.google.com/m8/feeds/contacts/eric%40example.com/base/0</id>
    <updated>2007-08-01T15:35:39.659Z</updated>
    <app:edited xmlns:app="http://www.w3.org/2007/app">2007-08-01T15:35:39.659Z</app:edited>
    <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
    <title>Sean</title>
    <link rel="http://schemas.google.com/contacts/2008/rel#photo" type="image/*" href="http://www.google.com/m8/feeds/photos/media/eric%40example.com/0"/>
    <link rel="self" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/0"/>
    <link rel="edit" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/0"/>
    <gd:email rel="http://schemas.google.com/g/2005#other" address="sean@example.com" primary="true"/>
  </entry>
  <entry gd:etag="&quot;QXk4fjVSLyp7ImA9WxVUGUwDRgE.&quot;">
    <id>http://www.google.com/m8/feeds/contacts/eric%40example.com/base/18</id>
    <updated>2009-03-24T18:25:50.736Z</updated>
    <app:edited xmlns:app="http://www.w3.org/2007/app">2009-03-24T18:25:50.736Z</app:edited>
    <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
    <title>Eric</title>
    <link rel="http://schemas.google.com/contacts/2008/rel#photo" type="image/*" href="http://www.google.com/m8/feeds/photos/media/eric%40example.com/18" gd:etag="&quot;UD9rbkUqSip7ImBkJkcZdVBoHxkeNFMKV1E.&quot;"/>
    <link rel="self" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/18"/>
    <link rel="edit" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/18"/>
    <gd:email rel="http://schemas.google.com/g/2005#other" address="eric@example.com" primary="true"/>
    <gd:email rel="http://schemas.google.com/g/2005#other" address="eric@example.net"/>
    <gd:im address="example" protocol="http://schemas.google.com/g/2005#AIM" rel="http://schemas.google.com/g/2005#other"/>
    <gd:phoneNumber rel="http://schemas.google.com/g/2005#mobile">999 555 1212</gd:phoneNumber>
    <gd:postalAddress rel="http://schemas.google.com/g/2005#home">123 Any Street
AnyTown, ZZ 99999</gd:postalAddress>
    <gContact:groupMembershipInfo deleted="false" href="http://www.google.com/m8/feeds/groups/eric%40example.com/base/6"/>
  </entry>
</feed>
  ATOM

  ##
  # Second page of contacts

  CONTACTS2 = <<-ATOM
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearch/1.1/" xmlns:gContact="http://schemas.google.com/contact/2008" xmlns:batch="http://schemas.google.com/gdata/batch" xmlns:gd="http://schemas.google.com/g/2005" gd:etag="W/&quot;CEYFQXkzfCp7ImA9WxVUGEg.&quot;">
  <id>eric@example.com</id>
  <updated>2009-03-23T23:48:30.784Z</updated>
  <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
  <title>drbrain's Contacts</title>
  <link rel="alternate" type="text/html" href="http://www.google.com/"/>
  <link rel="http://schemas.google.com/g/2005#feed" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full"/>
  <link rel="http://schemas.google.com/g/2005#post" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full"/>
  <link rel="http://schemas.google.com/g/2005#batch" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/batch"/>
  <link rel="self" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=3&amp;max-results=2"/>
  <link rel="previous" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=1&amp;max-results=2"/>
  <author>
    <name>drbrain</name>
    <email>eric@example.com</email>
  </author>
  <generator version="1.0" uri="http://www.google.com/m8/feeds">Contacts</generator>
  <openSearch:totalResults>4</openSearch:totalResults>
  <openSearch:startIndex>3</openSearch:startIndex>
  <openSearch:itemsPerPage>2</openSearch:itemsPerPage>
  <entry gd:etag="&quot;QXk_fTVSLyp7ImA9WxVUFUQITgA.&quot;">
    <id>http://www.google.com/m8/feeds/contacts/eric%40example.com/base/5834fb5d0b47bfd7</id>
    <updated>2009-03-20T23:49:00.745Z</updated>
    <app:edited xmlns:app="http://www.w3.org/2007/app">2009-03-20T23:49:00.745Z</app:edited>
    <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
    <title>Coby</title>
    <link rel="http://schemas.google.com/contacts/2008/rel#photo" type="image/*" href="http://www.google.com/m8/feeds/photos/media/eric%40example.com/5834fb5d0b47bfd7" gd:etag="&quot;eRJhPnolbCp7ImBjG0U0GBtuHmVAdnsJYzM.&quot;"/>
    <link rel="self" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/5834fb5d0b47bfd7"/>
    <link rel="edit" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/5834fb5d0b47bfd7"/>
    <gd:email rel="http://schemas.google.com/g/2005#other" address="coby@example.com" primary="true"/>
    <gContact:groupMembershipInfo deleted="false" href="http://www.google.com/m8/feeds/groups/eric%40example.com/base/6"/>
  </entry>
  <entry gd:etag="&quot;QXk_fTVSLyp7ImA9WxVUFUQITgAz&quot;">
    <id>http://www.google.com/m8/feeds/contacts/eric%40example.com/base/5834fb5d0b47bfdb</id>
    <updated>2009-03-20T23:49:00.745Z</updated>
    <app:edited xmlns:app="http://www.w3.org/2007/app">2009-03-20T23:49:00.745Z</app:edited>
    <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
    <title>No-email</title>
    <link rel="http://schemas.google.com/contacts/2008/rel#photo" type="image/*" href="http://www.google.com/m8/feeds/photos/media/eric%40example.com/5834fb5d0b47bfdb" gd:etag="&quot;eRJhPnolbCp7ImBjG0U0GBtuHmVAdnsJYzMz&quot;"/>
    <link rel="self" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/5834fb5d0b47bfdb"/>
    <link rel="edit" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric%40example.com/full/5834fb5d0b47bfdb"/>
    <gContact:groupMembershipInfo deleted="false" href="http://www.google.com/m8/feeds/groups/eric%40example.com/base/6"/>
  </entry>
</feed>
  ATOM

end

# :stopdoc:
class GmailContacts

  @stubbed = false

  attr_reader :http

  def self.stub
    return if @stubbed
    @stubbed = true

    alias old_get_token get_token

    def get_token
      if @authsub_token == 'recycled_authsub_token' then
        Net::HTTPForbidden.new(nil, '403', 'Forbidden').error!
      end

      @authsub_token = 'authsub_token-upgraded' if
        @authsub_token == 'authsub_token'
      @session_token = true

      @http.stub_reset
      @http.stub_data << GmailContacts::TestStub::CONTACTS
      @http.stub_data << GmailContacts::TestStub::CONTACTS2
    end

    alias old_fetch fetch

    def fetch(*args)
      if @authsub_token == 'wrong_user_authsub_token' then
        Net::HTTPForbidden.new(nil, '403', 'Forbidden').error!
      end

      old_fetch(*args)
    end

    alias old_fetch_photo fetch_photo

    def fetch_photo(contact)
      photo_url = if String === contact then
                    contact
                  else
                    contact.photo_url
                  end

      Net::HTTPNotFound.new(nil, '404', 'Not Found').error! if
        photo_url =~ /404/

      old_fetch_photo contact
    end

    alias old_revoke_token revoke_token

    def revoke_token
      @authsub_token = 'authsub_token-revoked'
      @session_token = false
    end

  end

end
# :startdoc:

class Net::HTTP::Persistent

  ##
  # Accessor for data the stub will return

  attr_accessor :stub_data

  ##
  # Accessor for URLs the stub accessed

  attr_accessor :stub_urls

  alias old_request request

  ##
  # Fetches +url+, records in stub_urls, and returns data if there's still
  # data in stub_data, or raises an exception

  def request(url)
    @stub_urls << url.to_s
    raise 'stub data empty' if @stub_data.empty?

    data = @stub_data.shift

    return data.call if Proc === data

    res = Net::HTTPOK.new nil, '200', 'OK'
    def res.body() @data end
    res.instance_variable_set :@data, data
    res
  end

  ##
  # Resets the stub to empty

  def stub_reset
    @stub_urls = []
    @stub_data = []
  end

end

