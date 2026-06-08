class PublicJobsController < ApplicationController
  layout "landing"

  def show
    @job = Quotation.find_by_share_token!(params[:token])

    unless @job.awaiting_driver_offers?
      render :closed, status: :gone
      return
    end

    return unless user_signed_in? && current_user.driver?

    @offer = @job.driver_offers.find_by(driver: current_user) || @job.driver_offers.new
  end
end
