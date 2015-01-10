class CreateSecretCoffeeTime < ActiveRecord::Migration
  def up
    create_table :secret_coffees do |t|
      t.datetime :time
      t.timestamps null: false
    end
  end

  def down
    drop_table :secret_coffees
  end
end
