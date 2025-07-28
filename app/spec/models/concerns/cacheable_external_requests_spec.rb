# spec/concerns/redis_method_cache_spec.rb
require 'rails_helper'

# note, this runs on local if you've got a redis setup, not doing in CI yet because just a spike of options
RSpec.describe CacheableExternalRequests do
  context "with postgres caching" do
    class DummyClient
      include CacheableExternalRequests

      def expensive_computation(foo:, bar:)
        @call_count ||= 0
        @call_count += 1
        { result: "#{foo}-#{bar}", count: @call_count }
      end

      cache_method :expensive_computation, expires_in: 60
    end

    before do
      stub_const("CacheableExternalRequests::CACHING_STRATEGY", :postgres)
    end

    let(:client) { DummyClient.new }
    it "caches the result of the method call in Redis" do
        result1 = client.expensive_computation(foo: "hello", bar: "world")
        result2 = client.expensive_computation(foo: "hello", bar: "world")

        expect(result1).to eq(result2.symbolize_keys)
        expect(result1[:count]).to eq(1) # ensures method wasn't re-run
      end
  end
  context "with redis caching" do
  class DummyClient
    include CacheableExternalRequests

    def expensive_computation(foo:, bar:)
      @call_count ||= 0
      @call_count += 1
      { result: "#{foo}-#{bar}", count: @call_count }
    end

    cache_method :expensive_computation, expires_in: 60
  end

  let(:client) { DummyClient.new }
  let(:redis) { Redis.current }

  before do
    redis.flushdb # clean slate before each test
  end

  it "caches the result of the method call in Redis" do
    result1 = client.expensive_computation(foo: "hello", bar: "world")
    result2 = client.expensive_computation(foo: "hello", bar: "world")

    expect(result1).to eq(result2.symbolize_keys)
    expect(result1[:count]).to eq(1) # ensures method wasn't re-run
  end

  it "creates a key in Redis for the cached result" do
    args = { foo: "x", bar: "y" }
    key = client.send(:redis_cache_key, :expensive_computation, args)
    expect(redis.get(key)).to be_nil

    client.expensive_computation(**args)

    expect(redis.get(key)).not_to be_nil
  end

  it "returns different cached values for different arguments" do
    result1 = client.expensive_computation(foo: "a", bar: "b")
    result2 = client.expensive_computation(foo: "a", bar: "c")

    expect(result1).not_to eq(result2)
  end

  it "respects the expiration time" do
    allow(Redis).to receive(:current).and_return(redis)
    client.expensive_computation(foo: "exp", bar: "test")

    key = client.send(:redis_cache_key, :expensive_computation, { foo: "exp", bar: "test" })
    ttl = redis.ttl(key)

    expect(ttl).to be <= 60
    expect(ttl).to be > 0
  end
end
end
