require 'rubygems'
require 'minitest/autorun'
require 'gmail_contacts'
require 'gmail_contacts/test_stub'
require 'pp'

class TestGmailContacts < MiniTest::Unit::TestCase

  def setup
    @gc = GmailContacts.new 'token'
    @api = @gc.contact_api
    @api.stub_reset

    @eric =
      GmailContacts::Contact.new('Eric', %w[eric@example.com eric@example.net],
                                 [%w[example http://schemas.google.com/g/2005#AIM]],
                                 [%w[999\ 555\ 1212 http://schemas.google.com/g/2005#mobile]],
                                 [["123 Any Street\nAnyTown, ZZ 99999",
                                   "http://schemas.google.com/g/2005#home"]],
                                 "http://www.google.com/m8/feeds/photos/media/eric%40example.com/18")
  end

  def test_fetch
    @api.stub_data << GmailContacts::TestStub::CONTACTS
    @api.stub_data << GmailContacts::TestStub::CONTACTS2

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
      res = GData::HTTP::Response.new
      raise GData::Client::AuthorizationError, res
    end

    assert_raises GData::Client::AuthorizationError do
      @gc.fetch 'notme@example.com'
    end

    assert_equal 0, @gc.contacts.length

    assert_equal 1, @api.stub_urls.length
    assert_equal 'http://www.google.com/m8/feeds/contacts/notme@example.com/full',
                 @api.stub_urls.shift

    assert @api.auth_handler.upgraded?
    assert @api.auth_handler.revoked?
  end

  def test_fetch_no_revoke
    @api.stub_data << GmailContacts::TestStub::CONTACTS
    @api.stub_data << GmailContacts::TestStub::CONTACTS2

    @gc.fetch 'eric@example.com', false

    assert_equal 3, @gc.contacts.length

    assert_equal 2, @api.stub_urls.length
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric@example.com/full',
                 @api.stub_urls.shift
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=3&max-results=2',
                 @api.stub_urls.shift

    assert @api.auth_handler.upgraded?
    refute @api.auth_handler.revoked?
  end

  def test_fetch_photo
    @api.stub_data << 'THIS IS A PHOTO!'

    photo = @gc.fetch_photo @eric

    assert_equal 'THIS IS A PHOTO!', photo
  end

  def test_parse
    @gc.parse Nokogiri::XML(GmailContacts::TestStub::CONTACTS)

    assert_equal 'eric@example.com', @gc.id
    assert_equal 'drbrain\'s Contacts', @gc.title
    assert_equal 'drbrain', @gc.author_name
    assert_equal 'eric@example.com', @gc.author_email

    photo_url = 'http://www.google.com/m8/feeds/photos/media/eric%40example.com/0'

    expected = [
      GmailContacts::Contact.new('Sean', %w[sean@example.com], [], [], [],
                                 photo_url),
      @eric
    ]

    assert_equal expected, @gc.contacts
  end

  def test_parse_two_pages
    @gc.parse Nokogiri::XML(GmailContacts::TestStub::CONTACTS)
    @gc.parse Nokogiri::XML(GmailContacts::TestStub::CONTACTS2)

    assert_equal 'eric@example.com', @gc.id
    assert_equal 'drbrain\'s Contacts', @gc.title
    assert_equal 'drbrain', @gc.author_name
    assert_equal 'eric@example.com', @gc.author_email

    sean_photo_url = "http://www.google.com/m8/feeds/photos/media/eric%40example.com/0"
    coby_photo_url = "http://www.google.com/m8/feeds/photos/media/eric%40example.com/5834fb5d0b47bfd7"

    expected = [
      GmailContacts::Contact.new('Sean', %w[sean@example.com], [], [], [],
                                 sean_photo_url),
      @eric,
      GmailContacts::Contact.new('Coby', %w[coby@example.com], [], [], [],
                                 coby_photo_url),
    ]

    assert_equal expected, @gc.contacts
  end

end

