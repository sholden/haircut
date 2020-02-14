require 'dotenv/load'
require 'net/http'
require 'json'
require 'logger'
require 'twilio-ruby'

account_sid = ENV['TWILIO_ACCOUNT_SID']
auth_token = ENV['TWILIO_AUTH_TOKEN']
from_number = ENV['TWILIO_FROM_NUMBER'] || raise('Twilio FROM number required')
to_number = ENV['TWILIO_TO_NUMBER'] || raise('Twilio TO number required')
princess_time = 'https://api.getsquire.com/v1/barber/6a84a164-1360-4abf-8998-38b47972d300/next-available-time'
princess_booking = 'https://online.getsquire.com/church-barber-and-apothecary-san-francisco/princess-pocaigue'

class TwilioNotifier
  attr_reader :client, :from_number, :to_number

  def initialize(account_sid, auth_token, from_number, to_number)
    @client = Twilio::REST::Client.new(account_sid, auth_token)
    @from_number = from_number
    @to_number = to_number
  end

  def notify(message)
    client.api.account.messages.create(
      from: from_number,
      to: to_number,
      body: message
    )
  end
end

logger = Logger.new(STDOUT)
notifier = TwilioNotifier.new(account_sid, auth_token, from_number, to_number)
earliest_time = ENV['HAIRCUT_AT'] &&  Time.parse(ENV['HAIRCUT_AT'])

build_msg = -> (time){
<<-MSG
Princess has an availability:
#{time.localtime.rfc2822}.
Go book that shit.
#{princess_booking}
MSG
}

logger.info "You need a damn haircut. Let's get you one."

loop do
  begin
    logger.info "Fetching earliest time..."
    resp = Net::HTTP.get(URI(princess_time))
    json = JSON.parse(resp)
    current_time = Time.parse(json['time'])

    if !earliest_time || current_time < earliest_time
      earliest_time = current_time
      message = build_msg.(earliest_time)
      logger.info message
      notifier.notify(message)
    end
  rescue StandardError => e
    logger.error "Some dumb shit: #{e}"
  end
  sleep 60 * 5
end
