module Driver
  class RecordLocation
    def self.call(quotation:, driver:, params:)
      new(quotation, driver, params).call
    end

    def initialize(quotation, driver, params)
      @quotation = quotation
      @driver = driver
      @params = params
    end

    def call
      eta = GoogleMaps::EtaCalculator.call(
        quotation: quotation,
        latitude: params[:latitude],
        longitude: params[:longitude]
      )

      DriverLocation.create!(
        quotation: quotation,
        driver: driver,
        latitude: params[:latitude],
        longitude: params[:longitude],
        accuracy_meters: params[:accuracy],
        heading: params[:heading],
        speed_mps: params[:speed],
        recorded_at: Time.current,
        eta_seconds: eta&.eta_seconds,
        eta_destination: eta&.destination_label
      )
    end

    private

    attr_reader :quotation, :driver, :params
  end
end
