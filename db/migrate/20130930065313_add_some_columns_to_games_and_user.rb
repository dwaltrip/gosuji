class AddSomeColumnsToGamesAndUser < ActiveRecord::Migration

  def change
    change_table :games do |t|
      t.string :description
      t.integer :type, :limit => 2
    end

    change_table :users do |t|
      t.string :password_digest
      t.string :rank
      t.index :email, unique: true
    end
  end

end
