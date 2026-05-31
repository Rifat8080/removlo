class AccountingCategory < ApplicationRecord
  CATEGORY_TYPES = {
    income: "income",
    expense: "expense",
    both: "both"
  }.freeze

  has_many :accounting_transactions, dependent: :restrict_with_error

  enum :category_type, CATEGORY_TYPES, default: :expense, validate: true

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :assign_slug, on: :create

  scope :ordered, -> { order(:name) }
  scope :for_income, -> { where(category_type: %w[income both]) }
  scope :for_expense, -> { where(category_type: %w[expense both]) }

  def self.default_for(transaction_type)
    slug =
      case transaction_type.to_s
      when "income" then "moving-services"
      when "refund" then "refunds"
      when "salary" then "salaries"
      when "commission" then "commissions"
      when "loan" then "loan-repayment"
      when "investment" then "investments"
      else "miscellaneous"
      end

    find_by(slug: slug)
  end

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
