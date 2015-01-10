class AddNotificationSentToSecretCoffee < ActiveRecord::Migration
  def up
    add_column :secret_coffees, :notification_sent, :boolean, default: false
  end

  def down
    remove_column :secret_coffees, :notification_sent
  end
end
