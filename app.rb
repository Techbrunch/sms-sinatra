require 'sinatra'
require 'twilio-ruby'
require 'unirest'
require 'json'
require 'prettyprint'
require 'pp'

def parse_sms(sms)
  case sms
  when /^(.*)#(.*)/
    return { origin: $1.strip, destination: $2.strip }
  else
    return nil
  end
end

post '/smsdirection' do
  content_type 'text/xml'

  message = params[:Body]
  message = message.downcase.strip

  parsed_sms = parse_sms(message)

  if parsed_sms.nil?
    twiml = Twilio::TwiML::Response.new do |r|
      r.Message 'Sorry we could not parse the sms. The format is: "origin # destination"'
    end
    return twiml.text
  else
    response = Unirest.get('https://maps.googleapis.com/maps/api/directions/json', headers: {}, parameters: parsed_sms)
    if response.nil? || response.body['status'] != 'OK'
      error = response.body['status']
      twiml = Twilio::TwiML::Response.new do |r|
        r.Message "Sorry, there was an error accessing the Google Map API: #{error}"
      end

      return twiml.text
    end
  end

  twiml = Twilio::TwiML::Response.new do |r|
    text = response.body["routes"].first["legs"].first["steps"][0..1].map{|s| s['html_instructions']}.join('%0a')
    r.Message do |m|
      m.Body text
    end
  end

  return twiml.text
end
