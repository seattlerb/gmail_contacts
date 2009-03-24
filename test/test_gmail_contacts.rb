require 'test/unit'
require 'gmail_contacts'
require 'pp'

class GData::Client::Contacts

  attr_accessor :stub_data,
                :stub_token,
                :stub_urls

  def authsub_token=(token)
    @stub_token = token
    auth_handler = Object.new
    def auth_handler.upgrade() @upgraded = true end
    def auth_handler.upgraded?() @upgraded end
    def auth_handler.revoke() @revoked = true end
    def auth_handler.revoked?() @revoked end
    self.auth_handler = auth_handler
  end

  def get(url)
    @stub_urls << url
    raise 'stub data empty' if @stub_data.empty?

    data = @stub_data.shift
    
    return data.call if Proc === data

    res = Object.new
    def res.body() @data end
    res.instance_variable_set :@data, data
    res
  end

  def stub_reset
    @stub_urls = []
    @stub_data = []
  end

end

class TestGmailContacts < Test::Unit::TestCase

  def setup
    @gc = GmailContacts.new 'token'
    @api = @gc.contact_api
    @api.stub_reset

    @eric = 
      GmailContacts::Contact.new('Eric', %w[eric@example.com eric@example.net],
                                 [%w[example http://schemas.google.com/g/2005#AIM]],
                                 [%w[999\ 555\ 1212 http://schemas.google.com/g/2005#mobile]],
                                 [["123 Any Street\nAnyTown, ZZ 99999",
                                   "http://schemas.google.com/g/2005#home"]])
  end

  def test_contact_pretty_print
    str = ''
    PP.pp @eric, str

    expected = <<-EXPECTED
Eric

  emails: eric@example.com (Primary), eric@example.net
  ims: example (AIM)
  phone numbers: 999 555 1212 (mobile)
  home address:
    123 Any Street
    AnyTown, ZZ 99999

    EXPECTED

    assert_equal expected, str
  end

  def test_fetch
    @api.stub_data << CONTACTS
    @api.stub_data << CONTACTS2

    @gc.fetch 'eric@example.com'

    assert_equal 3, @gc.contacts.length

    assert_equal 2, @api.stub_urls.length
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric@example.com/full',
                 @api.stub_urls.shift
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=3&max-results=2',
                 @api.stub_urls.shift

    assert @api.auth_handler.upgraded?
    assert @api.auth_handler.revoked?
  end

  def test_fetch_forbidden
    @api.stub_data << proc do
      raise GData::Client::AuthorizationError
    end

    assert_raise GData::Client::AuthorizationError do
      @gc.fetch 'notme@example.com'
    end

    assert_equal 0, @gc.contacts.length

    assert_equal 1, @api.stub_urls.length
    assert_equal 'http://www.google.com/m8/feeds/contacts/notme@example.com/full',
                 @api.stub_urls.shift

    assert @api.auth_handler.upgraded?
    assert @api.auth_handler.revoked?
  end

  def test_parse
    @gc.parse Nokogiri::XML(CONTACTS)

    assert_equal 'eric@example.com', @gc.id
    assert_equal 'drbrain\'s Contacts', @gc.title
    assert_equal 'drbrain', @gc.author_name
    assert_equal 'eric@example.com', @gc.author_email

    expected = [
      GmailContacts::Contact.new('Sean', %w[sean@example.com], [], [], []),
      @eric
    ]

    assert_equal expected, @gc.contacts
  end

  def test_parse_two_pages
    @gc.parse Nokogiri::XML(CONTACTS)
    @gc.parse Nokogiri::XML(CONTACTS2)

    assert_equal 'eric@example.com', @gc.id
    assert_equal 'drbrain\'s Contacts', @gc.title
    assert_equal 'drbrain', @gc.author_name
    assert_equal 'eric@example.com', @gc.author_email

    expected = [
      GmailContacts::Contact.new('Sean', %w[sean@example.com], [], [], []),
      @eric,
      GmailContacts::Contact.new('Coby', %w[coby@example.com], [], [], []),
    ]

    assert_equal expected, @gc.contacts
  end

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
  <openSearch:totalResults>3</openSearch:totalResults>
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
    <id>http://www.google.com/m8/feeds/contacts/eric.hodel%40gmail.com/base/18</id>
    <updated>2009-03-24T18:25:50.736Z</updated>
    <app:edited xmlns:app="http://www.w3.org/2007/app">2009-03-24T18:25:50.736Z</app:edited>
    <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
    <title>Eric</title>
    <link rel="http://schemas.google.com/contacts/2008/rel#photo" type="image/*" href="http://www.google.com/m8/feeds/photos/media/eric.hodel%40gmail.com/18" gd:etag="&quot;UD9rbkUqSip7ImBkJkcZdVBoHxkeNFMKV1E.&quot;"/>
    <link rel="self" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric.hodel%40gmail.com/full/18"/>
    <link rel="edit" type="application/atom+xml" href="http://www.google.com/m8/feeds/contacts/eric.hodel%40gmail.com/full/18"/>
    <gd:email rel="http://schemas.google.com/g/2005#other" address="eric@example.com" primary="true"/>
    <gd:email rel="http://schemas.google.com/g/2005#other" address="eric@example.net"/>
    <gd:im address="example" protocol="http://schemas.google.com/g/2005#AIM" rel="http://schemas.google.com/g/2005#other"/>
    <gd:phoneNumber rel="http://schemas.google.com/g/2005#mobile">999 555 1212</gd:phoneNumber>
    <gd:postalAddress rel="http://schemas.google.com/g/2005#home">123 Any Street
AnyTown, ZZ 99999</gd:postalAddress>
    <gContact:groupMembershipInfo deleted="false" href="http://www.google.com/m8/feeds/groups/eric.hodel%40gmail.com/base/6"/>
  </entry>
</feed>
  ATOM

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
  <openSearch:totalResults>3</openSearch:totalResults>
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
</feed>
  ATOM

end

