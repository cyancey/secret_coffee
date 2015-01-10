require 'sinatra'
require 'sinatra/activerecord'
require './environments'
require 'active_support/all'
require 'haml'


class SecretCoffee < ActiveRecord::Base
  validate :one_secret_coffee_run_per_day, on: :create

  def self.set_coffee_time
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")
    coffee_time = DateTime.new(now.year, now.month, now.day, 13, 0, 0, '-8') + rand(100).minutes
    SecretCoffee.create(time: coffee_time)
  end

  def self.secret_coffee_time?
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")
    todays_secret_coffees = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day).to_a

    todays_secret_coffees.map do |secret_coffee|
      (secret_coffee.time.in_time_zone("Pacific Time (US & Canada)") >= now) && (secret_coffee.time <= (now.in_time_zone("Pacific Time (US & Canada)") + 15.minutes))
    end.include?(true)

  end

  private

  def one_secret_coffee_run_per_day
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")
    coffee_runs_today = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day)
    if coffee_runs_today.size > 0
      errors.add(:base, 'You can only do one secret coffee run per day')
    end
  end
end

get '/' do
  @secret_coffee_time = SecretCoffee.secret_coffee_time?
  haml :home
end

get '/admin' do
  @secret_coffees = SecretCoffee.all
  haml :admin
end

get '/api' do
  content_type :json
  { secret_coffee_time: SecretCoffee.secret_coffee_time? }.to_json
end

