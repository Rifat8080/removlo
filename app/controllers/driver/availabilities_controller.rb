module Driver
  class AvailabilitiesController < BaseController
    def index
      @month = parse_month
      @availabilities = current_user.driver_availabilities.for_month(@month).order(:available_on)
      @availability = current_user.driver_availabilities.new(available_on: @month.beginning_of_month)
    end

    def create
      @availability = current_user.driver_availabilities.new(availability_params)

      if @availability.save
        redirect_to driver_availabilities_path(month: @availability.available_on.strftime("%Y-%m")), notice: "Availability saved."
      else
        @month = parse_month
        @availabilities = current_user.driver_availabilities.for_month(@month).order(:available_on)
        render :index, status: :unprocessable_entity
      end
    end

    def update
      @availability = current_user.driver_availabilities.find(params[:id])

      if @availability.update(availability_params)
        redirect_to driver_availabilities_path(month: @availability.available_on.strftime("%Y-%m")), notice: "Availability updated."
      else
        redirect_to driver_availabilities_path, alert: @availability.errors.full_messages.to_sentence
      end
    end

    def destroy
      @availability = current_user.driver_availabilities.find(params[:id])
      month = @availability.available_on.strftime("%Y-%m")
      @availability.destroy
      redirect_to driver_availabilities_path(month: month), notice: "Availability removed."
    end

    private

    def availability_params
      params.require(:driver_availability).permit(:available_on, :status, :notes)
    end

    def parse_month
      Date.strptime(params[:month].presence || Date.current.strftime("%Y-%m"), "%Y-%m")
    rescue ArgumentError
      Date.current.beginning_of_month
    end
  end
end
