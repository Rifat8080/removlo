class WebPushSubscription < ApplicationRecord
  belongs_to :user

  before_validation :normalize_endpoint

  validates :endpoint, :p256dh_key, :auth_key, presence: true
  validates :endpoint, uniqueness: true

  private

  def normalize_endpoint
    self.endpoint = endpoint.to_s.strip
  end
end
