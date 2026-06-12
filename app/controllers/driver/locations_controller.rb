module Driver
  class LocationsController < BaseController
    before_action :set_job

    def create
      unless @job.tracking_active? && @job.assigned_driver_id == current_user.id
        render json: { error: "Tracking is not available for this job." }, status: :forbidden
        return
      end

      location = RecordLocation.call(
        quotation: @job,
        driver: current_user,
        params: location_params
      )

      render json: {
        id: location.id,
        recorded_at: location.recorded_at.iso8601,
        eta_seconds: location.eta_seconds,
        eta_label: location.eta_label
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    private

    def set_job
      @job = Quotation.find(params[:job_id])
    end

    def location_params
      payload = params.permit(:latitude, :longitude, :accuracy, :heading, :speed)
      payload = params.require(:location).permit(:latitude, :longitude, :accuracy, :heading, :speed) if payload.blank? && params[:location].present?
      payload
    end
  end
end
