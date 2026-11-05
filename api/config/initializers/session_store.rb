# frozen_string_literal: true

Rails.application.config.session_store(
  :cookie_store,
  key: "_campsite_api_session",
  # Set SESSION_COOKIE_DOMAIN explicitly in self-hosted setups (for example
  # ".camp.aeskar.com") so the session is never sent to sibling services.
  # Falls back to upstream behavior (:all) only when unset.
  domain: ENV.fetch("SESSION_COOKIE_DOMAIN", :all),
  same_site: :lax,
  expire_after: 1.month,
  secure: Rails.env.production?,
)
