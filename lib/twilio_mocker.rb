require 'twilio-ruby'

class TwilioMocker
  include Twilio::REST::Utils

  API_VERSION = '2010-04-01'.freeze
  HOST = 'api.twilio.com'.freeze

  def initialize
    @username = Twilio.account_sid
    @token = Twilio.auth_token
  end

  def stub_create_message(attrs)
    body = twilify(attrs).map { |k, val| [k, val.to_s] }.to_h
    stub_request(:post, "#{base_twilio_url}/Messages.json")
      .with(body: body,  headers: headers, basic_auth: basic_auth)
      .to_return(status: 200, body: response, headers: {})
  end

  def stub_available_numbers
    response_numbers = {
      sid: @username,
      available_phone_numbers: [{ 'PhoneNumber' => TwilioNumberGenerator.instance.generate }]
    }.to_json
    stub_request(:get, "#{base_twilio_url}/AvailablePhoneNumbers/US/Local.json")
      .with(headers: headers, basic_auth: basic_auth)
      .to_return(status: 200, body: response_numbers, headers: {})
  end

  def stub_buy_number(attrs)
    body = twilify(attrs).map { |k, val| [k, val.to_s] }.to_h
    stub_request(:post, "#{base_twilio_url}/IncomingPhoneNumbers.json")
      .with(body: body, headers: headers, basic_auth: basic_auth)
      .to_return(status: 200, body: response, headers: {})
  end

  private

  def response
    {
      sid: @username
    }.to_json
  end

  def headers
    Twilio::REST::Client::HTTP_HEADERS
  end

  def basic_auth
    [@username, @token]
  end

  def stub_request(method, url)
    WebMock.stub_request(method, url)
  end

  def base_twilio_url
    "https://#{HOST}/#{API_VERSION}/Accounts/#{@username}"
  end
end
