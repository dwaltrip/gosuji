redis_url = ENV["REDIS_URL"]

$redis =
  if redis_url
    uri = URI.parse(redis_url)
    Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    Redis.new
  end

Rails.logger.info "---- inside redis.rb ---- $redis= #{$redis.inspect}"
