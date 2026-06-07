class DriverAvailability < ApplicationRecord
  STATUSES = {
    available: "available",
    busy: "busy",
    holiday: "holiday",
    off_duty: "off_duty"
  }.freeze

  belongs_to :driver, class_name: "User"

  enum :status, STATUSES, default: :available, validate: true

  validates :available_on, presence: true, uniqueness: { scope: :driver_id }
  validate :driver_must_be_driver

  scope :for_month, ->(date) { where(available_on: date.beginning_of_month..date.end_of_month) }
  scope :available_on_date, ->(date) { where(available_on: date, status: "available") }

  def available?
    status == "available"
  end

  private

  def driver_must_be_driver
    return if driver.blank? || driver.driver?

    errors.add(:driver, "must have the driver role")
  end
end
