require 'sinatra'
require 'sinatra/activerecord'
require 'active_support/all'
require 'haml'
require 'httparty'
require 'dotenv'
require 'sinatra/flash'

enable :sessions

Dotenv.load

def now
  Time.now.in_time_zone("Pacific Time (US & Canada)")
end

class SecretCoffeeSetting < ActiveRecord::Base
  validates :range_start_time, presence: true
  validates :range_length_minutes, presence: true
end

class SecretCoffee < ActiveRecord::Base
  validate :one_secret_coffee_run_per_day, on: :create
  belongs_to :coffee_quote

  def self.set_coffee_time
    secret_coffee_setting = SecretCoffeeSetting.last
    secret_coffee_hour = secret_coffee_setting.range_start_time.in_time_zone("Pacific Time (US & Canada)").hour
    secret_coffee_minute = secret_coffee_setting.range_start_time.in_time_zone("Pacific Time (US & Canada)").min
    range_length = secret_coffee_setting.range_length_minutes
    coffee_time = Time.new(now.year, now.month, now.day, secret_coffee_hour, secret_coffee_minute) + rand(range_length).minutes
    SecretCoffee.create(time: coffee_time, coffee_quote: CoffeeQuote.random)
  end

  def self.secret_coffee_time?
    todays_secret_coffees = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day)

    todays_secret_coffees.map do |secret_coffee|
      (now < (secret_coffee.time + 15.minutes)) && (now > secret_coffee.time)
    end.include?(true)
  end

  def self.scheduled_today
    @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last
    !@secret_coffee.nil?
  end

  def self.already_happened_today
    @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last
    if @secret_coffee
      Time.now > (@secret_coffee.time + 15.minutes)
    else
      false
    end
  end

  def self.status_message
    if SecretCoffee.secret_coffee_time?
      message = "It's secret coffee time."
    elsif SecretCoffee.already_happened_today
      message = "It's not secret coffee time. Today's run already happened."
    elsif SecretCoffee.scheduled_today
      message = "It's not secret coffee time. A run is scheduled for today."
    else
      message = "It's not secret coffee time. A run is not scheduled for today."
    end
  end

  def to_slack_message
    message = "Drop what you're doing. It's time for secret coffee."
    quote = self.coffee_quote
    if self.coffee_quote
      message << "\n\n#{quote.to_slack_message}"
    end
    message
  end

  private

  def one_secret_coffee_run_per_day
    coffee_time = self.time.in_time_zone("Pacific Time (US & Canada)")
    coffee_runs_today = SecretCoffee.where(time: coffee_time.beginning_of_day..coffee_time.end_of_day)
    if coffee_runs_today.size > 0
      puts "Couldn't create new secret coffee run"
      coffee_runs_today.each do |secret_coffee|
        p secret_coffee.as_json
      end
      errors.add(:base, 'You can only do one secret coffee run per day')
    end
  end
end

class CoffeeQuote < ActiveRecord::Base
  has_many :secret_coffees

  def self.random
    CoffeeQuote.offset(rand(CoffeeQuote.count)).first
  end

  def to_slack_message
    "\"#{self.quote}\"\n- #{self.said_by}"
  end
end

module Slack
  extend self

  def post_message(message)
    HTTParty.post(ENV['SLACK_WEBHOOK'], body: {text: message}.to_json)
  end
end

def convert_hour_for_no_period(hour, period)
  if hour == 12
    hour
  elsif period == 'PM'
    hour + 12
  else
    hour
  end
end

def convert_hour_for_use_with_period(hour)
  if hour > 12
    hour - 12
  else
    hour
  end
end

def time_period(hour)
  if hour > 11
    'PM'
  else
    'AM'
  end
end

get '/' do
  now = Time.now.in_time_zone("Pacific Time (US & Canada)")
  @secret_coffee_time = SecretCoffee.secret_coffee_time?
  @secret_coffee_status_message = SecretCoffee.status_message
  @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last
  @quote = @secret_coffee.coffee_quote if @secret_coffee

  haml :home
end

# get '/admin' do
#   if params[:pw] == ENV['ADMIN_PASSWORD']
#     @secret_coffees = SecretCoffee.order(:time)
#     haml :admin
#   else
#     redirect to('/')
#   end
# end

get '/api' do
  content_type :json

  now = Time.now.in_time_zone("Pacific Time (US & Canada)")
  @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last

  if !SecretCoffee.secret_coffee_time?
    { secret_coffee_time: false,
      scheduled_today: SecretCoffee.scheduled_today,
      already_happened: SecretCoffee.already_happened_today,
      status_message: SecretCoffee.status_message }.to_json
  else
    @quote = @secret_coffee.coffee_quote
    if @quote
      { secret_coffee_time: true,
        status_message: SecretCoffee.status_message,
        coffee_quote: {quote: @quote.quote,
                       said_by: @quote.said_by}}.to_json
    else
      { secret_coffee_time: true,
        status_message: SecretCoffee.status_message,
        coffee_quote: nil}.to_json
    end
  end
end

get '/slack_request' do
  content_type :text
  SecretCoffee.status_message
end

get '/settings' do
  secret_coffee_setting = SecretCoffeeSetting.last
  if secret_coffee_setting
    start_time = secret_coffee_setting.range_start_time.in_time_zone("Pacific Time (US & Canada)")
    end_time = start_time + secret_coffee_setting.range_length_minutes.minutes

    @start_hour = convert_hour_for_use_with_period(start_time.hour)
    @start_minute = start_time.min
    @start_period = time_period(start_time.hour)

    @end_hour = convert_hour_for_use_with_period(end_time.hour)
    @end_minute = end_time.min
    @end_period = time_period(end_time.hour)
  else
    @start_hour = nil
    @start_minute = nil
    @start_period = nil
    @end_hour = nil
    @end_minute = nil
    @end_period = nil
  end

  haml :settings
end

post '/settings' do
  puts params

  start_minute = params['start_minute'].to_i
  start_period = params['start-period']
  start_hour = convert_hour_for_no_period(params['start-hour'].to_i, start_period)
  end_minute = params['end-minute'].to_i
  end_period = params['end-period']
  end_hour = convert_hour_for_no_period(params['end-hour'].to_i, end_period)

  start_time = Time.new(2000, 1, 1, start_hour, start_minute)
  end_time = Time.new(2000, 1, 1, end_hour, end_minute)

  if start_time > end_time
    flash[:error] = 'Start time cannot be before end time.'
  else
    minute_difference = (end_time - start_time) / 60

    secret_coffee_setting = SecretCoffeeSetting.new(range_start_time: start_time,
                                                    range_length_minutes: minute_difference)

    if secret_coffee_setting.save
      flash[:success] = 'Save Successful'
    else
      flash[:error] = secret_coffee_setting.errors
    end
  end

  redirect to('/settings')
end

