require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) 

module GoApp

  MIN_BOARD_SIZE = 7
  BOARD_SIZE = 19
  MAX_BOARD_SIZE = 35

  EMPTY_TILE = nil
  BLACK_STONE = false
  WHITE_STONE = true

  BOARD_SIZES = (7..19).to_a
  STAR_POINTS = Hash.new

  class Application < Rails::Application
    config.active_record.schema_format = :ruby

    # load modules/classes from lib folder
    config.autoload_paths += Dir["#{config.root}/lib/**/"]

    config.after_initialize do
      BOARD_SIZES.each do |size|
        STAR_POINTS[size] = StarPoints::positions_for_board_size(size)
      end
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
  end
end
