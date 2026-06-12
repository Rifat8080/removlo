class DriverLocation < ApplicationRecord
  belongs_to :quotation
  belongs_to :driver, class_name: "User"

  validates :latitude, :longitude, :recorded_at, presence: true
  validate :driver_must_match_assignment

  scope :recent, -> { order(recorded_at: :desc) }
  scope :chronological, -> { order(recorded_at: :asc) }

  after_commit :broadcast_tracking_update, on: :create

  def self.latest_for(quotation)
    where(quotation: quotation).recent.first
  end

  def eta_label
    return "Updating..." if eta_seconds.blank?

    minutes = (eta_seconds / 60.0).ceil
    return "Less than 1 min" if minutes < 1

    hours, mins = minutes.divmod(60)
    return "#{hours}h #{mins}m" if hours.positive?

    "#{mins} min"
  end

  private

  def driver_must_match_assignment
    return if quotation.blank? || driver.blank?
    return if quotation.assigned_driver_id == driver_id

    errors.add(:driver, "must be the assigned driver for this job")
  end

  def broadcast_tracking_update
    partial_locals = { quotation: quotation, location: self }

    Turbo::StreamsChannel.broadcast_replace_to(
      quotation,
      :tracking,
      target: dom_id(quotation, :tracking_panel),
      partial: "quotations/tracking_panel",
      locals: partial_locals
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      quotation,
      :driver_tracking,
      target: dom_id(quotation, :driver_tracking_panel),
      partial: "driver/jobs/tracking_panel",
      locals: partial_locals
    )
  end

  def dom_id(record, prefix = nil)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end
end
