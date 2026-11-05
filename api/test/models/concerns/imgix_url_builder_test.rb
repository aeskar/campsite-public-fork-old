# frozen_string_literal: true

require "test_helper"

class ImgixUrlBuilderTest < ActiveSupport::TestCase
  class Builder
    include ImgixUrlBuilder
  end

  ENV_KEYS = ["IMGIX_URL", "IMGIX_FOLDER_URL", "IMGIX_VIDEO_URL"].freeze

  setup do
    @saved_env = ENV.to_h.slice(*ENV_KEYS)
    ENV_KEYS.each { |key| ENV.delete(key) }
  end

  teardown do
    ENV_KEYS.each { |key| ENV.delete(key) }
    @saved_env.each { |key, value| ENV[key] = value }
  end

  context "with only ENV set (no Imgix credentials)" do
    setup do
      Rails.application.credentials.stubs(:dig).returns(nil)
      ENV["IMGIX_URL"] = "https://img.camp.localhost"
      ENV["IMGIX_FOLDER_URL"] = "https://api.camp.localhost"
      ENV["IMGIX_VIDEO_URL"] = "https://img.camp.localhost"
    end

    test "build_imgix_url uses IMGIX_URL" do
      url = Builder.new.build_imgix_url("o/abc/p/file.png", { w: 64, h: 64, fit: "crop" })

      assert_equal "https://img.camp.localhost/o/abc/p/file.png?fit=crop&h=64&w=64", url
    end

    test "build_imgix_url keeps an empty dl value" do
      assert_equal "https://img.camp.localhost/o/abc/p/file.png?dl=", Builder.new.build_imgix_url("o/abc/p/file.png", dl: "")
    end

    test "folder and video URLs use their ENV values" do
      assert_equal "https://api.camp.localhost/v1/notes/x/thumbnails/y", Builder.new.build_imgix_folder_url("/v1/notes/x/thumbnails/y")
      assert_equal "https://img.camp.localhost/o/abc/v.mp4", Builder.new.build_imgix_video_url("o/abc/v.mp4")
    end

    test "module-level base_url works without including the concern (class-level reads)" do
      assert_equal "https://img.camp.localhost", ImgixUrlBuilder.base_url
    end
  end

  test "falls back to credentials when ENV is not set" do
    assert_equal Rails.application.credentials.imgix.url, ImgixUrlBuilder.base_url
  end

  test "ENV takes precedence over credentials" do
    ENV["IMGIX_URL"] = "https://img.camp.localhost"

    assert_equal "https://img.camp.localhost", ImgixUrlBuilder.base_url
  end
end
