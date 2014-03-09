# GoSuji - Rails app for playing Go

[Check out the live app!](http://gosuji.herokuapp.com)

Go is a timeless board game originating in China more than two millenia ago. It has relatively simple rules, and yet the strategy is very deep and rich. It is one of the few classic board games where the best humans still have an edge against computers. Read more about Go on [wikipedia](http://en.wikipedia.org/wiki/Go_(game)).

GoSuji is a straightforward implemenation of the game. It has real-time moves, automatically saved game progress, a nifty behind-the-scenes board analyzer that makes scoring the game very simple, and in-game chat. Users can find their active and finished games on the profile page. Open games to join can be found on the home page of the site, which also has the link for creating new games.

## The Stack

GoSuji was built using modern web development tools:

* Ruby on Rails
  - The large majority of all application logic. Everything except for websockets is handled by Rails
  - [POROs](http://blog.jayfields.com/2007/10/ruby-poro.html) are utilized to process moves and scoring actions (/lib directory). This helps maintain separation of concerns and keeps the models skinnier.
* Node.js & websockets
  - A [separate Node.js app](https://github.com/dwaltrip/gosuji-node-server) is used to handle the realtime aspects of the site
  - Receives data from Rails (via Redis) and sends this data to the necessary clients via websockets
  - Uses the SockJS websocket library, and a [wrapper I created](http://github.com/dwaltrip/sockjs-wrapper) that adds socket.io style named events and rooms on top of SockJS.
* Redis
  - Provides pub-sub messaging layer that allows Rails to send data to the Node.js app
  - Serves as a quick access data-store that holds temporary data during the game scoring phase
* Many of the other usual suspects
  - jQuery, vanilla javascript, CSS, HTML
  - Rspec, Capybara + Poltergeist for testing


## Coming soon...

The basic set of features is  fully implemented and working beautifully (see first section for a brief description). However, I have many exciting ideas to make GoSuji even more awesome.
In the works:
* User-created custom rooms where people can hang out, chat, and create games to play against others
* Timed games, with a wide range of settings (from blitz to leisurely turn based games)
* Game review, where one can navigate the moves of a finished game and try alternate sequences
* Exporting of games to SGF (smart game format)
* Self-balancing ranking system that aligns with the widely used kyu and dan ranks
* API for allowing user-created bots to play on the site
* Custom board shapes! This is the feature I am most excited about. There are a lot of possibilities with this idea. I will probably start with some simpler pre-set custom shapes, and then later build an interface that lets users create and share their own custom boards

## Setting up and running GoSuji locally

1. Install the dependencies (older versions may work for some of these)
  1. Ruby 1.9.3 or higher
  2. Rails 4.0.0 or higher
  3. Node.js 0.10.0 or higher
  4. npm 1.2.0 or higher
  5. Redis 2.4 or higher
  6. PostgreSQL or SQLite

2. Setup the Rails app
  1. Clone the repository: `git clone https://github.com/dwaltrip/gosuji.git`
  2. Install gems: `bundle install`
  3. Setup environment variables. The [figaro gem](https://github.com/laserlemon/figaro) is used to manage these.
    1. Change the name of `config/application-(example).yml` to `config/application.yml`.
    1. If you aren't using the default port for Redis or you modify the port used by the Node.js app, you will need to edit the `development:` section of `application.yml` to reflect this.
  4. Change the name of `config/database-(example).yml` to `config/database.yml`. To use PostgreSQL instead of SQLite, see [this Railscast](http://railscasts.com/episodes/342-migrating-to-postgresql).
  5. Run the database migrations: `bundle exec rake db:migrate`.

3. Setup the Node app
  1. Clone the repository: `git clone https://github.com/dwaltrip/gosuji-node-server.git`
  2. Install packages: `npm install`
  3. Change the name of `development-config-(example).js` to `development-config.js`. Edit this file if you are not using the default port for redis.

4. Run the tests and verify that they pass (Optional)
  1. The gameplay integration tests use [Poltergiest](https://github.com/jonleighton/poltergeist), which depends on PhantomJS. Follow [these instructions](https://github.com/jonleighton/poltergeist#installing-phantomjs) to install it. Alternatively, you can skip this portion of the test suite. To do so, open `spec/features/gameplay_actions_spec.rb` and, at the top of the file, change `feature "gameplay actions" do` to `feature "gameplay actions", skip: true do`.
  2. Migrate the test database: `bundle exec rake db:migrate RAILS_ENV=test`
  3. If including the integration tests, start up Node and Redis (see section 5)
  4. Run the tests: `bundle exec rspec`

5. Run GoSuji!
  1. Start the Redis server: `redis-server` (my dev machine starts a background Redis process on start up, so I skip this step)
  2. Start the Rails server: `rails server`
  3. Start the Node.js server: `node server.js`
  4. Open your browser and visit `localhost:3000`. Go is a two player game, so you will have to open a second browser to play against yourself :)
