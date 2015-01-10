require './app'
require 'sinatra/activerecord/rake'

namespace :secret_coffee do

  desc 'Set secret coffee time for today'
  task :set_time do
    SecretCoffee.set_coffee_time
  end

  desc "Send notification for secret coffee if it hasn't been sent"
  task :send_notification_if_coffee_time do
    if SecretCoffee.secret_coffee_time?
      today = Time.now.in_time_zone("Pacific Time (US & Canada)")
      todays_coffee_runs = SecretCoffee.where(time: today.beginning_of_day..today.end_of_day)

      notification_sent_for_todays_runs = todays_coffee_runs.map do |secret_coffee|
        secret_coffee.notification_sent
      end.include?(true)

      unless notification_sent_for_todays_runs
        ## send notification

        ## mark all todays runs as having notifications sent
        todays_coffee_runs.each {|secret_coffee| secret_coffee.update_attributes(notification_sent: true)}
      end

    end
  end

end
