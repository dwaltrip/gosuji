source 'https://rubygems.org'
ruby '1.9.3'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.0.0'

gem 'figaro'
gem 'redis', "~> 3.0.1"

# Use postgresql as the database for Active Record
gem 'pg', '0.15.1'

gem 'bcrypt-ruby', '3.0.1'

group :development, :test do
  gem 'thin'
  gem 'rspec-rails', '~> 2.13'
  gem 'debugger'

  ## used for more advanced testing set-up
  #gem 'guard-rspec', '2.5.0'
end

group :test do
  gem 'selenium-webdriver', '2.35.1'
  gem 'capybara', '2.1.0'

  # avoid annoying I18n warning during rspec testing
  gem 'i18n', '>= 0.6.9'

  ## used for more advanced testing set-up
  #gem 'rb-notifu', '0.0.4'
  #gem 'win32console', '1.3.2'
  #gem 'wdm', '0.1.0'

  ## used for more advanced testing set-up
  #gem 'spork-rails', '4.0.0'
  #gem 'guard-spork', '1.5.0'
  #gem 'childprocess', '0.3.9'
end

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '2.1.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails', '3.0.4'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '1.0.2'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', '0.3.20', require: false
end

group :production do
  gem 'rails_12factor', '0.0.2'
end
