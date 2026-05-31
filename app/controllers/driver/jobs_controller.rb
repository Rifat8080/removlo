module Driver
  class JobsController < BaseController
    before_action :set_job, only: :show

    def index
      @jobs = Quotation.includes(:customer).for_driver(current_user)
    end

    def show
    end

    private

    def set_job
      @job = Quotation.for_driver(current_user).find(params[:id])
    end
  end
end
