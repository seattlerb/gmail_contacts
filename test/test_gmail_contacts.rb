require 'rubygems'
require 'minitest/autorun'
require 'gmail_contacts'
require 'gmail_contacts/test_stub'
require 'pp'

class TestGmailContacts < MiniTest::Unit::TestCase

  def setup
    @gc = GmailContacts.new 'token', true
    @http = @gc.http
    @http.stub_reset

    @eric =
      GmailContacts::Contact.new('Eric', %w[eric@example.com eric@example.net],
                                 [%w[example http://schemas.google.com/g/2005#AIM]],
                                 [%w[999\ 555\ 1212 http://schemas.google.com/g/2005#mobile]],
                                 [["123 Any Street\nAnyTown, ZZ 99999",
                                   "http://schemas.google.com/g/2005#home"]],
                                 "http://www.google.com/m8/feeds/photos/media/eric%40example.com/18")
  end

  def test_initialize
    assert_equal 'AuthSub token="token"', @http.headers['Authorization']
    assert_match %r%_\d+$%, @http.name
  end

  def test_fetch
    @http.stub_data << GmailContacts::TestStub::CONTACTS
    @http.stub_data << GmailContacts::TestStub::CONTACTS2
    @http.stub_data << ''

    @gc.fetch 'eric@example.com'

    assert_equal 3, @gc.contacts.length

    assert_equal 3, @http.stub_urls.length
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric@example.com/full',
                 @http.stub_urls.shift
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=3&max-results=2',
                 @http.stub_urls.shift
    assert_equal 'https://www.google.com/accounts/AuthSubRevokeToken',
                 @http.stub_urls.shift
  end

  def test_fetch_auto_upgrade
    @gc = GmailContacts.new 'token'
    @http = @gc.http
    @http.stub_reset
    @http.stub_data << ''
    @http.stub_data << GmailContacts::TestStub::CONTACTS
    @http.stub_data << GmailContacts::TestStub::CONTACTS2
    @http.stub_data << ''

    @gc.fetch 'eric@example.com'

    assert_equal 3, @gc.contacts.length

    assert_equal 4, @http.stub_urls.length
    assert_equal 'https://www.google.com/accounts/AuthSubSessionToken',
                 @http.stub_urls.shift
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric@example.com/full',
                 @http.stub_urls.shift
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=3&max-results=2',
                 @http.stub_urls.shift
    assert_equal 'https://www.google.com/accounts/AuthSubRevokeToken',
                 @http.stub_urls.shift
  end

  def test_fetch_no_revoke
    @http.stub_data << GmailContacts::TestStub::CONTACTS
    @http.stub_data << GmailContacts::TestStub::CONTACTS2

    @gc.fetch 'eric@example.com', false

    assert_equal 3, @gc.contacts.length

    assert_equal 2, @http.stub_urls.length
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric@example.com/full',
                 @http.stub_urls.shift
    assert_equal 'http://www.google.com/m8/feeds/contacts/eric%40example.com/full?start-index=3&max-results=2',
                 @http.stub_urls.shift
  end

  def test_fetch_photo
    @http.stub_data << 'THIS IS A PHOTO!'

    photo = @gc.fetch_photo @eric

    assert_equal 'THIS IS A PHOTO!', photo
  end

  def test_fetch_photo_url
    @http.stub_data << 'THIS IS A PHOTO!'

    photo = @gc.fetch_photo @eric.photo_url

    assert_equal 'THIS IS A PHOTO!', photo
  end

  def test_get_token
    assert @gc.token?, 'sanity, we should already have a session token'

    assert_nil @gc.get_token
  end

  def test_get_token_non_session
    @gc = GmailContacts.new 'token'
    @http = @gc.http
    @http.stub_reset
    @http.stub_data << 'Token=new token'

    @gc.get_token

    assert @gc.token?
    assert_equal 'new token', @gc.authsub_token
    assert_equal 'AuthSub token="new token"', @http.headers['Authorization']

    assert_equal 1, @http.stub_urls.length
    assert_equal 'https://www.google.com/accounts/AuthSubSessionToken',
                 @http.stub_urls.shift
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

  def test_request
    @http.stub_data << 'blah'

    res = @gc.request 'http://example'

    assert_equal 'blah', res.body
  end

  def test_request_unsuccessful
    @http.stub_data << proc do
      Net::HTTPForbidden.new nil, '403', 'Forbidden'
    end

    assert_raises Net::HTTPServerException do
      @gc.request 'http://example'
    end
  end

  def test_revoke_token
    @http.stub_data << ''

    @gc.revoke_token

    refute @gc.token?

    assert_equal 1, @http.stub_urls.length
    assert_equal 'https://www.google.com/accounts/AuthSubRevokeToken',
                 @http.stub_urls.shift
  end

  def test_token_eh
    assert @gc.token?

    refute GmailContacts.new.token?
  end

end

