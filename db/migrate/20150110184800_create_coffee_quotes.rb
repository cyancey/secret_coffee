class CreateCoffeeQuotes < ActiveRecord::Migration
  def up
    create_table :coffee_quotes do |t|
      t.text :quote, null: false
      t.string :said_by
      t.timestamps null: false
    end

    change_table :secret_coffees do |t|
      t.belongs_to :coffee_quote
    end
  end

  def down
    drop_table :coffee_quotes
    remove_column :secret_coffees, :coffee_quote_id
  end
end
