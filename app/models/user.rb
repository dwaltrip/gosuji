class User < ActiveRecord::Base
  has_many :games_as_player1, :class_name => 'Game', :foreign_key => :player1_id
  has_many :games_as_player2, :class_name => 'Game', :foreign_key => :player2_id

  def games
    games_as_player1 + games_as_player2
  end

  before_save { self.email = email.downcase }
  validates :username, presence: true, length: { minimum: 2, maximum: 20}
  # regex comes from chapter 6 of rails tutorial
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i
  # uniqueness isn't 100% guaranteed, so we must enforce it in the db also
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false }

  # will use following code later for authentication, etc:
  #has_secure_password
  #validates :password, length: { minimum: 6 }
end
