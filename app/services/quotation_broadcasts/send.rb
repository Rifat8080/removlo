module QuotationBroadcasts
  class Send
    def self.call(broadcast:, actor:)
      new(broadcast, actor).call
    end

    def initialize(broadcast, actor)
      @broadcast = broadcast
      @actor = actor
      @quotation = broadcast.quotation
    end

    def call
      drivers = broadcast.matching_drivers
      broadcast.update!(drivers_notified_count: drivers.size)
      quotation.update!(awaiting_driver_offers: true)

      drivers.each do |driver|
        ::ActivityNotifier.call(
          recipients: driver,
          event_type: "quotation.driver_job_broadcast",
          title: "New job available",
          body: "Job #{quotation.reference} is open for offers.",
          url: Rails.application.routes.url_helpers.driver_job_path(quotation),
          actor: actor,
          notifiable: quotation
        )
      end

      drivers
    end

    private

    attr_reader :broadcast, :actor, :quotation
  end
end
