# frozen_string_literal: true

require "test_helper"

class SelfhostConfigTest < ActionDispatch::IntegrationTest
  INITIALIZER = Rails.root.join("config/initializers/session_store.rb")

  # The session store middleware is built once at boot, so to exercise the
  # initializer under a given environment we re-evaluate it and drive a minimal
  # Rack stack built from the resulting session options.
  def session_set_cookie_header(cookie_domain:)
    original = ENV["SESSION_COOKIE_DOMAIN"]
    cookie_domain ? ENV["SESSION_COOKIE_DOMAIN"] = cookie_domain : ENV.delete("SESSION_COOKIE_DOMAIN")
    load(INITIALIZER)

    app = ->(env) {
      env["rack.session"]["probe"] = "1"
      [200, { "content-type" => "text/plain" }, ["ok"]]
    }
    stack = ActionDispatch::Cookies.new(
      ActionDispatch::Session::CookieStore.new(app, **Rails.application.config.session_options),
    )
    env = Rack::MockRequest.env_for("https://auth.camp.localhost/", Rails.application.env_config)
    _status, headers, _body = stack.call(env)
    Array(headers["set-cookie"] || headers["Set-Cookie"]).join("\n")
  ensure
    original ? ENV["SESSION_COOKIE_DOMAIN"] = original : ENV.delete("SESSION_COOKIE_DOMAIN")
    load(INITIALIZER)
  end

  test "session cookie uses SESSION_COOKIE_DOMAIN" do
    header = session_set_cookie_header(cookie_domain: ".camp.localhost")

    assert_match(/_campsite_api_session=/, header)
    assert_match(/domain=\.camp\.localhost/i, header)
  end

  test "session cookie keeps the upstream :all behavior when SESSION_COOKIE_DOMAIN is unset" do
    header = session_set_cookie_header(cookie_domain: nil)

    assert_match(/domain=camp\.localhost;/i, header)
  end

  test "production boot fails without SESSION_COOKIE_DOMAIN" do
    original = ENV["SESSION_COOKIE_DOMAIN"]
    Rails.env.stubs(:production?).returns(true)

    ["", nil].each do |value|
      value ? ENV["SESSION_COOKIE_DOMAIN"] = value : ENV.delete("SESSION_COOKIE_DOMAIN")
      error = assert_raises(RuntimeError) { load(INITIALIZER) }
      assert_match(/SESSION_COOKIE_DOMAIN must be set in production/, error.message)
    end

    ENV["SESSION_COOKIE_DOMAIN"] = ".camp.aeskar.com"
    load(INITIALIZER)
    assert_equal(".camp.aeskar.com", Rails.application.config.session_options[:domain])
  ensure
    Rails.env.unstub(:production?)
    original ? ENV["SESSION_COOKIE_DOMAIN"] = original : ENV.delete("SESSION_COOKIE_DOMAIN")
    load(INITIALIZER)
  end

  test "production guard is skipped for the image build (SECRET_KEY_BASE_DUMMY)" do
    original = ENV.values_at("SESSION_COOKIE_DOMAIN", "SECRET_KEY_BASE_DUMMY")
    Rails.env.stubs(:production?).returns(true)
    ENV.delete("SESSION_COOKIE_DOMAIN")
    ENV["SECRET_KEY_BASE_DUMMY"] = "1"

    assert_nothing_raised { load(INITIALIZER) }

    ENV.delete("SECRET_KEY_BASE_DUMMY")
    assert_raises(RuntimeError) { load(INITIALIZER) }
  ensure
    Rails.env.unstub(:production?)
    ["SESSION_COOKIE_DOMAIN", "SECRET_KEY_BASE_DUMMY"].zip(original).each do |k, v|
      v ? ENV[k] = v : ENV.delete(k)
    end
    load(INITIALIZER)
  end

  test "ADMIN_SUBDOMAIN overrides the admin subdomain" do
    assert_equal("admin", Campsite.admin_subdomain)

    ENV["ADMIN_SUBDOMAIN"] = "ops"
    assert_equal("ops", Campsite.admin_subdomain)
  ensure
    ENV.delete("ADMIN_SUBDOMAIN")
  end

  test "boots without optional integrations" do
    credentials = Rails.application.credentials
    [:slack, :linear, :figma, :hms, :tenor, :sentry, :postmark, :rack_attack].each do |key|
      credentials.stubs(key).returns(nil)
    end
    credentials.stubs(:dig).returns(nil)

    host! "auth.campsite.com"
    get "/sign-in"

    assert_response :ok
  end

  test "rack attack SSR safelist never matches without a configured secret" do
    safelist = Rack::Attack.safelists.fetch("mark server-side rendering requests safe")
    request = Rack::Request.new(Rack::MockRequest.env_for("/", "HTTP_X_CAMPSITE_SSR_SECRET" => ""))
    anonymous = Rack::Request.new(Rack::MockRequest.env_for("/"))

    assert_not safelist.matched_by?(request)
    assert_not safelist.matched_by?(anonymous)
  end
end
