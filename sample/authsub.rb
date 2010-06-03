require 'rubygems'
require 'webrick'
require 'gmail_contacts'

webrick = WEBrick::HTTPServer.new :Port => 3000

webrick.mount_proc '/' do |req, res|
  res.content_type = 'text/html'

  ##
  # This is the initial page, a form with an email to fetch contacts for

  if req.path == '/' then
    res.body = <<-BODY
<form action="http://#{Socket.gethostname}:3000/go">
<input name="email">
<input type="submit" value="go">
</form>
    BODY

  ##
  # This is where we redirect the user to Google for approval, click "grant"
  # on that page.

  elsif req.path == '/go' then
    gmail_contacts = GmailContacts.new
    url = gmail_contacts.authsub_url \
      "http://localhost:3000/return?email=#{req.query['email']}"
    res.set_redirect WEBrick::HTTPStatus::SeeOther, url

  ##
  # Google sends us back here, so we create a new GmailContacts with the token
  # they gave us and fetch the contacts for the email provided to /go

  elsif req.path == '/return' then
    res.body = "<h1>contacts</h1>\n"

    begin
      gmail_contacts = GmailContacts.new req.query['token'].to_s

      email = req.query['email']

      gmail_contacts.fetch email

      res.body << "<h1>contacts</h1>\n\n<ul>\n"

      gmail_contacts.contacts.each do |contact|
        res.body << "<li>#{contact.title} - #{contact.primary_email}\n"
      end

      res.body << "</ul>\n"
    rescue => e
      res.body << <<-BODY
<h1>error</h1>

<p>#{e.message}

<pre>#{e.backtrace.join "\n"}</pre>
      BODY
    end
  end
end

trap 'INT'  do webrick.shutdown end
trap 'TERM' do webrick.shutdown end

webrick.start

