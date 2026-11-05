# frozen_string_literal: true

require "nanoid"

module ImgixUrlBuilder
  extend ActiveSupport::Concern

  FALLBACK_AVATAR_COLORS = [
    "3b82f6", # blue.500
    "4ade80", # green.400
    "fde047", # yellow.300
    "ef4444", # red.500
    "9333ea", # purple.300
    "ec4899", # pink.500
    "6366f1", # indigo.500
    "5eead4", # teal.300
  ].freeze

  # Base URLs are read from ENV first, Rails credentials as fallback, so a
  # self-hosted deploy (imgproxy gateway) needs no Imgix credentials. Module
  # functions, so class-level constants (Project::ORG_DEFAULT_PROJECTS) and
  # non-including classes can use them too.
  def self.base_url
    ENV["IMGIX_URL"].presence || Rails.application.credentials.dig(:imgix, :url)
  end

  def self.folder_base_url
    ENV["IMGIX_FOLDER_URL"].presence || Rails.application.credentials.dig(:imgix_folder, :url)
  end

  def self.video_base_url
    ENV["IMGIX_VIDEO_URL"].presence || Rails.application.credentials.dig(:imgix_video, :url)
  end

  def fallback_avatar(name = "", append_params = {})
    color = FALLBACK_AVATAR_COLORS[name.each_byte.sum % FALLBACK_AVATAR_COLORS.length]
    build_imgix_url("static/avatars/#{name[0] ? name[0].upcase : "blank"}.png", append_params.merge("blend-color": color))
  end

  def build_imgix_url(path, append_params = {})
    uri = Addressable::URI.parse(ImgixUrlBuilder.base_url)
    uri.path = path
    if append_params.present?
      uri.query_values = append_params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end

  def build_imgix_folder_url(path, append_params = {})
    uri = Addressable::URI.parse(ImgixUrlBuilder.folder_base_url)
    uri.path = path
    if append_params.present?
      uri.query_values = append_params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end

  def build_imgix_video_url(path, append_params = {})
    uri = Addressable::URI.parse(ImgixUrlBuilder.video_base_url)
    uri.path = path
    if append_params.present?
      uri.query_values = append_params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end
end
