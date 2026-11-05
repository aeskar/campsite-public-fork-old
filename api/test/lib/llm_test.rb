# frozen_string_literal: true

require "test_helper"
require "webmock"

class LlmTest < ActiveSupport::TestCase
  include WebMock::API

  API_URL = "https://api.anthropic.com/v1/messages"

  setup do
    @original_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-dummy-key"
    # VCR hooks into Faraday and would reject requests made outside a cassette, so
    # these tests switch it off and stub the HTTP layer with WebMock instead.
    VCR.turn_off!
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  teardown do
    ENV["ANTHROPIC_API_KEY"] = @original_key
    VCR.turn_on!
    WebMock.reset!
    WebMock.allow_net_connect!
    WebMock.disable!
  end

  def ok_response(text = "hello")
    { status: 200, headers: { "Content-Type" => "application/json" }, body: { content: [{ type: "text", text: text }] }.to_json }
  end

  test "sends system messages as the system field" do
    stub = stub_request(:post, API_URL)
      .with(
        headers: { "x-api-key" => "test-dummy-key", "anthropic-version" => "2023-06-01" },
        body: hash_including("system" => "S", "messages" => [{ "role" => "user", "content" => "U" }], "model" => "claude-sonnet-5-5", "max_tokens" => 2048, "temperature" => 0.0),
      )
      .to_return(ok_response)

    Llm.new.chat(messages: [{ role: "system", content: "S" }, { role: "user", content: "U" }])

    assert_requested stub
    pass
  end

  test "joins several system messages with a blank line" do
    stub = stub_request(:post, API_URL)
      .with(body: hash_including("system" => "A\n\nB"))
      .to_return(ok_response)

    Llm.new.chat(messages: [{ role: "system", content: "A" }, { role: "system", content: "B" }, { role: "user", content: "U" }])

    assert_requested stub
    pass
  end

  test "omits the system field when there are no system messages" do
    stub_request(:post, API_URL).to_return(ok_response)

    Llm.new.chat(messages: [{ role: "user", content: "U" }])

    assert_requested(:post, API_URL) { |req| !JSON.parse(req.body).key?("system") }
    pass
  end

  test "uses the model passed in or LLM_MODEL" do
    stub_request(:post, API_URL).to_return(ok_response)

    Llm.new(model: "claude-test-model").chat(messages: [{ role: "user", content: "U" }])

    assert_requested(:post, API_URL) { |req| JSON.parse(req.body)["model"] == "claude-test-model" }
    pass
  end

  test "returns the text of the first content block" do
    stub_request(:post, API_URL).to_return(ok_response("hello"))

    assert_equal "hello", Llm.new.chat(messages: [{ role: "user", content: "U" }])
  end

  test "raises on HTTP error" do
    stub_request(:post, API_URL).to_return(status: 500, body: "{}")

    assert_raises(Faraday::ServerError) do
      Llm.new.chat(messages: [{ role: "user", content: "U" }])
    end
  end
end
