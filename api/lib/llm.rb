# frozen_string_literal: true

class Llm
  API_URL = "https://api.anthropic.com/v1/messages"
  API_VERSION = "2023-06-01"
  MAX_TOKENS = 2048
  TIMEOUT = 120

  def initialize(model: ENV.fetch("LLM_MODEL", "claude-sonnet-5-5"))
    @model = model
  end

  def chat(messages:, temperature: 0.0)
    system_messages, conversation = messages.partition { |m| m[:role].to_s == "system" }

    body = {
      model: @model,
      max_tokens: MAX_TOKENS,
      temperature: temperature,
      messages: conversation.map { |m| { role: m[:role].to_s, content: m[:content] } },
    }
    body[:system] = system_messages.pluck(:content).join("\n\n") if system_messages.any?

    response = connection.post(API_URL, body)
    response.body.dig("content", 0, "text")
  end

  private

  def connection
    Faraday.new(request: { timeout: TIMEOUT }) do |f|
      f.request(:json)
      f.response(:raise_error)
      f.response(:json)
      f.headers["x-api-key"] = api_key
      f.headers["anthropic-version"] = API_VERSION
    end
  end

  def api_key
    ENV["ANTHROPIC_API_KEY"].presence || Rails.application.credentials.dig(:anthropic, :api_key) || raise("ANTHROPIC_API_KEY is not set")
  end
end
