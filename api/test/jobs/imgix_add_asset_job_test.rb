# frozen_string_literal: true

require "test_helper"

class ImgixAddAssetJobTest < ActiveJob::TestCase
  context "perform" do
    test "calls ImgixClient" do
      origin_path = "o/foklwviisxc1/p/6c6c54a9-e7ad-4a73-b990-62fd4f8a2e1c.png"

      ImgixClient.any_instance.expects(:add_asset).with(
        source_id: Rails.application.credentials.dig(:imgix, :source_id),
        origin_path: origin_path,
      )

      ImgixAddAssetJob.new.perform(origin_path)
    end

    test "is a no-op without an Imgix API key" do
      Rails.application.credentials.stubs(:dig).with(:imgix, :api_key).returns(nil)
      ImgixClient.expects(:new).never

      ImgixAddAssetJob.new.perform("o/foklwviisxc1/p/video.mp4")
    end
  end
end
