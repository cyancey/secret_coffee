require './app'
require 'sinatra/activerecord/rake'

namespace :secret_coffee do

  desc 'Set secret coffee time for today'
  task :set_time do
    SecretCoffee.set_coffee_time
  end

  desc "Send notification for secret coffee if it hasn't been sent"
  task :send_notification_if_coffee_time do
    now = Time.now.in_time_zone("Pacific Time (US & Canada)")
    todays_coffee_runs = SecretCoffee.where(time: now.beginning_of_day..now.end_of_day)

    send_notification = todays_coffee_runs.map do |secret_coffee|
      !secret_coffee.notification_sent && (secret_coffee.time <= now)
    end.include?(true)

    if send_notification
      ## send notification
      Slack.post_message(todays_coffee_runs.last.to_slack_message)
      ## mark all todays runs as having notifications sent
      todays_coffee_runs.each {|secret_coffee| secret_coffee.update_attributes(notification_sent: true)}
    end

  end

end
