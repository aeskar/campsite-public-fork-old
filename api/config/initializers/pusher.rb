# frozen_string_literal: true

# Self-hosting: Pusher-compatible servers (Soketi) are configured from ENV first, with the Rails
# credentials as fallback. PUSHER_HOST, PUSHER_PORT and PUSHER_SCHEME point the client at the
# server; when PUSHER_HOST is unset the gem talks to Pusher Channels as upstream does.
Pusher.app_id = ENV["PUSHER_APP_ID"].presence || Rails.application.credentials.dig(:pusher, :app_id)
Pusher.key = ENV["PUSHER_KEY"].presence || Rails.application.credentials.dig(:pusher, :key)
Pusher.secret = ENV["PUSHER_SECRET"].presence || Rails.application.credentials.dig(:pusher, :secret)

if ENV["PUSHER_HOST"].present?
  Pusher.host = ENV["PUSHER_HOST"]
  Pusher.scheme = ENV["PUSHER_SCHEME"] if ENV["PUSHER_SCHEME"].present?
  Pusher.port = ENV["PUSHER_PORT"].to_i if ENV["PUSHER_PORT"].present?
else
  Pusher.cluster = Rails.application.credentials.dig(:pusher, :cluster)
end
