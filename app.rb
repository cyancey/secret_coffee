require 'sinatra'
require 'sinatra/activerecord'
require 'active_support/all'
require 'haml'
require 'httparty'
require 'dotenv'

Dotenv.load

class SecretCoffee < ActiveRecord::Base
  validate :one_secret_coffee_run_per_day, on: :create
  belongs_to :coffee_quote

  def self.set_coffee_time
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")
    coffee_time = DateTime.new(now.year, now.month, now.day, 13, 0, 0, '-8') + rand(100).minutes
    SecretCoffee.create(time: coffee_time, coffee_quote: CoffeeQuote.random)
  end

  def self.secret_coffee_time?
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")
    todays_secret_coffees = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day)

    todays_secret_coffees.map do |secret_coffee|
      (now < (secret_coffee.time + 15.minutes)) && (now > secret_coffee.time)
    end.include?(true)
  end

  def self.scheduled_today
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")

    @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last
    !@secret_coffee.nil?
  end

  def self.already_happened_today
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")

    @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last
    if @secret_coffee
      Time.now > (@secret_coffee.time + 15.minutes)
    else
      false
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

get '/' do
  @secret_coffee_time = SecretCoffee.secret_coffee_time?

  if @secret_coffee_time
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")
    @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last
    @quote = @secret_coffee.coffee_quote if @secret_coffee
  else
    @already_happened_today = SecretCoffee.already_happened_today
    @scheduled_today = SecretCoffee.scheduled_today
  end

  haml :home
end

get '/admin' do
  if params[:pw] == ENV['ADMIN_PASSWORD']
    @secret_coffees = SecretCoffee.order(:time)
    haml :admin
  else
    redirect to('/')
  end
end

get '/api' do
  content_type :json

  now = Time.now.in_time_zone("Pacific Time (US & Canada)")
  @secret_coffee = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).last

  if !SecretCoffee.secret_coffee_time?
    { secret_coffee_time: false,
      scheduled_today: SecretCoffee.scheduled_today,
      already_happened: SecretCoffee.already_happened_today }.to_json
  else
    @quote = @secret_coffee.coffee_quote
    if @quote
      { secret_coffee_time: true,
        coffee_quote: {quote: @quote.quote,
                       said_by: @quote.said_by}}.to_json
    else
      { secret_coffee_time: true,
        coffee_quote: nil}.to_json
    end
  end
end

get '/slack_request' do
  if SecretCoffee.secret_coffee_time?
    text = "It's secret coffee time."
  elsif SecretCoffee.already_happened_today
    text = "It's not secret coffee time. Today's run already happened."
  elsif SecretCoffee.scheduled_today
    text = "It's not secret coffee time. A run is scheduled for today."
  else
    text = "It's not secret coffee time. A run is not scheduled for today."
  end

  content_type :text
  text
end
