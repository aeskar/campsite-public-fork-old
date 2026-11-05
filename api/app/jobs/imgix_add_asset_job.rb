# frozen_string_literal: true

class ImgixAddAssetJob < BaseJob
  sidekiq_options queue: "background", retry: 3

  def perform(origin_path)
    api_key = Rails.application.credentials.dig(:imgix, :api_key)
    if api_key.blank?
      # Self-hosted image gateway (imgproxy) reads S3 directly; nothing to register.
      Rails.logger.info("[ImgixAddAssetJob] No Imgix API key, skipping #{origin_path}")
      return
    end

    client = ImgixClient.new(api_key: api_key)
    client.add_asset(source_id: Rails.application.credentials.dig(:imgix, :source_id), origin_path: origin_path)
  end
end
