class AddSecretCoffeeSettings < ActiveRecord::Migration
  def up
  	create_table :secret_coffee_settings do |t|
  		t.datetime :range_start_time
  		t.integer :range_length_minutes
  		t.timestamps
  	end
  end

  def down
  	drop_table :secret_coffee_settings
  end
end
