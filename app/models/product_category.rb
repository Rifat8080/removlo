class ProductCategory < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :assign_slug, on: :create

  scope :ordered, -> { order(:position, :name) }

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
