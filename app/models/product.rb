class Product < ApplicationRecord
  STATUSES = { active: "active", inactive: "inactive" }.freeze
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  belongs_to :product_category, optional: true
  has_many :cart_items, dependent: :restrict_with_error
  has_many :material_order_items, dependent: :nullify

  has_one_attached :image

  enum :status, STATUSES, default: :active, validate: true

  validates :name, :slug, :sku, presence: true
  validates :slug, :sku, uniqueness: true
  validates :price_cents, :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :image_must_be_valid_image

  before_validation :assign_slug, on: :create

  scope :available, -> { active.where("stock_quantity > 0") }
  scope :featured, -> { available.where(featured: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :catalog, -> { active.order(featured: :desc, name: :asc) }
  scope :by_param, ->(param) {
    if param.to_s.match?(/\A\d+\z/)
      where(id: param)
    else
      where(slug: param)
    end
  }

  def price
    price_cents.to_i / 100.0
  end

  def in_stock?
    stock_quantity.to_i.positive?
  end

  def to_param
    slug
  end

  def self.find_by_param!(param)
    by_param(param).first!
  end

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end

  def image_must_be_valid_image
    return unless image.attached?

    unless image.blob.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(:image, "must be a PNG, JPG, WEBP, or GIF image")
    end

    if image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:image, "must be smaller than 5MB")
    end
  end
end
