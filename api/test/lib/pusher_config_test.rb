# frozen_string_literal: true

require "test_helper"

class PusherConfigTest < ActiveSupport::TestCase
  INITIALIZER = Rails.root.join("config/initializers/pusher.rb")
  ENV_KEYS = ["PUSHER_HOST", "PUSHER_PORT", "PUSHER_SCHEME", "PUSHER_APP_ID", "PUSHER_KEY", "PUSHER_SECRET"].freeze

  setup do
    @original_env = ENV.to_h.slice(*ENV_KEYS)
    ENV_KEYS.each { |key| ENV.delete(key) }
    Pusher.instance_variable_set(:@default_client, nil)
  end

  teardown do
    ENV_KEYS.each { |key| ENV.delete(key) }
    @original_env.each { |key, value| ENV[key] = value }
    Pusher.instance_variable_set(:@default_client, nil)
    load(INITIALIZER)
  end

  test "points the client at a self-hosted server from ENV" do
    ENV["PUSHER_HOST"] = "soketi"
    ENV["PUSHER_PORT"] = "6001"
    ENV["PUSHER_SCHEME"] = "http"
    load(INITIALIZER)

    assert_match(%r{\Ahttp://soketi:6001}, Pusher.default_client.url.to_s)
  end

  test "defaults to https on the standard port when only PUSHER_HOST is set" do
    ENV["PUSHER_HOST"] = "ws.camp.example.com"
    load(INITIALIZER)

    assert_equal "ws.camp.example.com", Pusher.default_client.host
    assert_match(%r{\Ahttps://ws\.camp\.example\.com}, Pusher.default_client.url.to_s)
  end

  test "reads app id, key and secret from ENV before credentials" do
    ENV["PUSHER_APP_ID"] = "app-1"
    ENV["PUSHER_KEY"] = "key-1"
    ENV["PUSHER_SECRET"] = "secret-1"
    load(INITIALIZER)

    assert_equal "app-1", Pusher.app_id
    assert_equal "key-1", Pusher.key
    assert_equal "secret-1", Pusher.secret
  end

  test "keeps the Pusher Channels host when PUSHER_HOST is unset" do
    load(INITIALIZER)

    assert_match(/pusher\.com\z|pusherapp\.com\z/, Pusher.default_client.host.to_s)
  end
end
