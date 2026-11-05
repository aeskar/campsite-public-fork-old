# frozen_string_literal: true

cookie_domain = ENV["SESSION_COOKIE_DOMAIN"].presence

if Rails.env.production? && cookie_domain.nil?
  raise "SESSION_COOKIE_DOMAIN must be set in production (for example \".camp.aeskar.com\"); " \
    "refusing to fall back to :all because the session cookie would be shared with sibling services."
end

Rails.application.config.session_store(
  :cookie_store,
  key: "_campsite_api_session",
  # Set SESSION_COOKIE_DOMAIN explicitly in self-hosted setups (for example
  # ".camp.aeskar.com") so the session is never sent to sibling services.
  # Required in production (boot fails without it); development and test fall back to :all.
  domain: cookie_domain || :all,
  same_site: :lax,
  expire_after: 1.month,
  secure: Rails.env.production?,
)
