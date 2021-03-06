require 'spec_helper'

RSpec.describe TwilioMock::Mocker do
  let(:client) { Twilio::REST::Client.new('example', 'example') }
  let(:available_numbers) { client.api.account.available_phone_numbers('US').local.list({}) }
  let(:first_available_number) { available_numbers.first.phone_number }
  let(:number_generator) { TwilioMock::NumberGenerator.instance }
  let(:sms_url) { 'test.host/callback' }

  describe 'get available phone number' do
    it 'returns a test number' do
      expect(first_available_number).to match(/150055/)
    end

    context "with area code" do
      let(:available_numbers) { client.api.account.available_phone_numbers('US').local.list(area_code: "123") }

      it 'returns a test number with the correct area code' do
        expect(first_available_number).to match(/112355/)
      end
    end

    context "with a different country" do
      let(:available_numbers) { client.api.account.available_phone_numbers('BR').local.list({}) }

      it 'returns a test number' do
        expect(first_available_number).to match(/150055/)
      end
    end

    context "when asking to return an empty list" do
      let(:mocker) { TwilioMock::Mocker.new }
      before { mocker.available_number_list(empty_available_list: true)}
      let(:available_numbers) { client.api.account.available_phone_numbers('US').local.list({}) }
      it 'returns an empty list' do
        TwilioMock::Testing.disable! do
          expect(available_numbers).to be_empty
        end
      end
    end
  end

  describe 'get incoming_phone_numbers list' do
    let(:mocker) { TwilioMock::Mocker.new }

    let(:number_1) { number_generator.generate }
    let(:number_2) { number_generator.generate }

    before { mocker.incoming_number_list([number_1, number_2])}
    let(:incoming_phone_numbers) { client.api.account.incoming_phone_numbers.list }
    it 'returns the correct number list' do
      expect(incoming_phone_numbers.size).to eq(2)
    end

    it 'returns the correct number' do
      expect(incoming_phone_numbers.first.phone_number).to eq(number_1)
    end
  end

  describe 'buy a number' do
    it 'calls the incoming api' do
      expect_any_instance_of(TwilioExtensions::IncomingPhoneNumbers).to receive(:create)

      client.api.account.incoming_phone_numbers.create(
        phone_number: first_available_number,
        sms_url: sms_url,
        sms_method: 'POST'
      )
    end
  end

  describe 'fetches a message' do
    let(:mocker) { TwilioMock::Mocker.new }
    let(:sid) { "SM#{Digest::MD5.hexdigest(rand.to_s)}" }
    let(:status) { "failed" }
    let(:error_code) { 30004 }
    let(:error_message) { "Message blocked" }
    let(:messages) { client.api.account.messages(sid) }
    let(:message_params) {
      {
        error_code: error_code,
        error_message: error_message,
        status: status
      }
    }
    before { mocker.fetch_message(sid, message_params) }
    it 'returns message with correct attributes' do
      message = messages.fetch
      expect(message.error_code).to eq error_code
      expect(message.error_message).to eq error_message
      expect(message.status).to eq status
      expect(message.sid).to eq sid
    end
  end

  describe 'fetches a number' do
    let(:mocker) { TwilioMock::Mocker.new }
    let(:sid) { "SM#{Digest::MD5.hexdigest(rand.to_s)}" }
    let(:phone_number) { number_generator.generate }
    let(:numbers) { client.api.account.incoming_phone_numbers(sid) }
    let(:phone_params) {
      {
        phone_number: phone_number,
      }
    }
    before { mocker.fetch_number(sid, phone_params) }
    it 'returns number with correct attributes' do
      number = numbers.fetch
      expect(number.sid).to eq sid
      expect(number.phone_number).to eq phone_number
    end
  end

  describe 'sends a sms' do
    let(:from) { first_available_number }
    let(:to)   { '+15005550003' }
    let(:body) { 'Example' }
    let(:params) do
      {
        from: from,
        to: to,
        body: body
      }
    end

    it 'calls the message creation' do
      expect_any_instance_of(TwilioExtensions::Messages).to receive(:create)

      client.api.account.messages.create(params)
    end

    it 'adds to the messages queue' do
      client.api.account.messages.create(params)

      message = TwilioMock::Mocker.new.messages.last
      expect(message.from).to eq from
      expect(message.to).to eq to
      expect(message.body).to eq body
    end

    it 'returns madatory attributes' do
      response = client.api.account.messages.create(params)
      expect(response.body).to eq(body)
      expect(response.sid).to match(/\ASM[a-z\d]{32}\Z/)
      expect(response.status).to eq("queued")
      expect(response.to).to eq(to)
    end

    context 'two messages' do
      before do
        client.api.account.messages.create(params)
        client.api.account.messages.create(params)
      end

      it 'the queue has 2 elements' do
        expect(TwilioMock::Mocker.new.messages.count).to eq 2
      end
    end
  end
end
