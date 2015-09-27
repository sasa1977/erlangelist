defmodule Erlangelist.RateLimiterTest do
  use ExUnit.Case

  alias Erlangelist.RateLimiter

  test "rate limiter" do
    RateLimiter.start_link(:test_limiter_1, 10)
    RateLimiter.start_link(:test_limiter_2, :timer.minutes(1))

    assert true == RateLimiter.allow?(:test_limiter_1, :foo, 1)
    assert false == RateLimiter.allow?(:test_limiter_1, :foo, 1)

    assert true == RateLimiter.allow?(:test_limiter_2, :foo, 1)
    assert false == RateLimiter.allow?(:test_limiter_2, :foo, 1)

    assert true == RateLimiter.allow?(:test_limiter_1, :bar, 2)
    assert true == RateLimiter.allow?(:test_limiter_1, :bar, 2)
    assert false == RateLimiter.allow?(:test_limiter_1, :bar, 2)

    :timer.sleep(50)
    assert true == RateLimiter.allow?(:test_limiter_1, :foo, 1)
    assert true == RateLimiter.allow?(:test_limiter_1, :bar, 2)
    assert false == RateLimiter.allow?(:test_limiter_2, :foo, 1)
  end
end