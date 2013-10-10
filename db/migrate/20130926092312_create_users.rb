class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :username, :null => false
      t.string :password_digest
      t.string :email
      t.integer :status, :limit => 2
      t.string :rank
      t.text :account_settings

      t.timestamps
    end

    add_index :users, :username, :unique => true
    add_index :users, :email
  end
end
