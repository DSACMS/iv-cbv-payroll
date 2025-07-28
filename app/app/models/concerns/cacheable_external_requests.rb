# app/models/concerns/cacheable_external_requests.rb
module CacheableExternalRequests
  extend ActiveSupport::Concern

  CACHING_STRATEGY = :redis

  included do
    def redis_cache_fetch(method_name, args, expires_in:)
      key = redis_cache_key(method_name, args)
      cached = Redis.current.get(key)
      return JSON.parse(cached) if cached

      result = send("uncached_#{method_name}", **args)
      Redis.current.setex(key, expires_in.to_i, result.to_json)
      result
    end

    def redis_cache_key(method_name, args)
      digest = Digest::SHA256.hexdigest(args.to_json)
      "#{self.class.name.underscore}:#{method_name}:#{digest}"
    end

    # assuming we've used https://github.com/rails/solid_cache?tab=readme-ov-file as our backing store
    def postgres_cache_fetch(method_name, args, expires_in:)
      key = postgres_cache_key(method_name, args)


      Rails.cache.fetch(key, expires_in: expires_in) do
        send("uncached_#{method_name}", **args)
      end
    end

    def postgres_cache_key(method_name, args)
      digest = Digest::SHA256.hexdigest(args.to_json)
      "#{self.class.name.underscore}/#{method_name}/#{digest}"
    end
  end

  class_methods do
    def cache_method(method_name, expires_in: 5.minutes)
      alias_method "uncached_#{method_name}", method_name

      define_method(method_name) do |**args|
        if CACHING_STRATEGY == :redis
          redis_cache_fetch(method_name, args, expires_in: expires_in)
        elsif CACHING_STRATEGY == :postgres
          postgres_cache_fetch(method_name, args, expires_in: expires_in)
        end
      end
    end
  end
end
