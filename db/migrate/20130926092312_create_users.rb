class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :username, :email
      t.text :account_settings

      t.timestamps
    end
  end
end
