module Quotations
  class PostForDrivers
    def self.call(quotation:, actor: nil)
      new(quotation, actor).call
    end

    def initialize(quotation, actor = nil)
      @quotation = quotation
      @actor = actor
    end

    def call
      return quotation if quotation.awaiting_driver_offers?

      quotation.update!(awaiting_driver_offers: true)
      notify_all_drivers
      quotation
    end

    private

    attr_reader :quotation, :actor

    def notify_all_drivers
      ::ActivityNotifier.call(
        recipients: User.drivers,
        event_type: "quotation.driver_job_alert",
        title: "New job alert",
        body: "Job #{quotation.reference} is open for offers.",
        url: Rails.application.routes.url_helpers.driver_job_path(quotation),
        actor: actor,
        notifiable: quotation
      )
    end
  end
end
