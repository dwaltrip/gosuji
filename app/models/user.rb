class User < ActiveRecord::Base
  has_many :games_as_black_player, :class_name => 'Game', :foreign_key => :black_player_id
  has_many :games_as_white_player, :class_name => 'Game', :foreign_key => :white_player_id
  has_many :games_as_creator, :class_name => 'Game', :foreign_key => :creator_id

  def games
    games_as_black_player + games_as_white_player
  end

  before_save { self.email = email.downcase }
  validates :username, presence: true, length: { minimum: 2, maximum: 20}

  # only validate email if not blank
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i
  validates :email, format: { with: VALID_EMAIL_REGEX },
    uniqueness: { case_sensitive: false },
    unless: Proc.new { |u| u.email.blank? }

  # has_secure_password gives us validation for password and confirmation
  # also creates password_digest and the method 'authenticate' for user instances
  has_secure_password
  validates :password, length: { minimum: 6 }
end
