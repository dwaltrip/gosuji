redistogo_url = ENV["REDISTOGO_URL"]

$redis =
  if redistogo_url
    uri = URI.parse(redistogo_url)
    Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    Redis.new
  end

Rails.logger.info "---- inside redis.rb ---- $redis= #{$redis.inspect}"
