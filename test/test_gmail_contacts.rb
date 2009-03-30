require 'test/unit'
require 'gmail_contacts'
require 'gmail_contacts/test_stub'
require 'pp'

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
    @gc.parse Nokogiri::XML(GmailContacts::TestStub::CONTACTS)

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
    @gc.parse Nokogiri::XML(GmailContacts::TestStub::CONTACTS)
    @gc.parse Nokogiri::XML(GmailContacts::TestStub::CONTACTS2)

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

end

