class BlogPost < ApplicationRecord
  belongs_to :author, class_name: "User"
  has_one_attached :cover_image

  validates :title, :body, :published_at, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :cover_image_must_be_valid_image

  before_validation :assign_defaults

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  def to_param
    slug
  end

  private

  def cover_image_must_be_valid_image
    return unless cover_image.attached?

    unless cover_image.blob.content_type.in?(%w[image/png image/jpeg image/webp image/gif])
      errors.add(:cover_image, "must be a PNG, JPG, WEBP, or GIF image")
    end

    if cover_image.blob.byte_size > 5.megabytes
      errors.add(:cover_image, "must be smaller than 5MB")
    end
  end

  def assign_defaults
    self.published_at ||= Time.current
    self.slug = parameterized_slug if slug.blank? || will_save_change_to_title?
  end

  def parameterized_slug
    base_slug = title.to_s.parameterize.presence || SecureRandom.hex(4)
    candidate = base_slug
    counter = 2

    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    candidate
  end
end
