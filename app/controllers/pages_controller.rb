class PagesController < ApplicationController
  before_action :authenticate_user!, only: :dashboard

  layout "landing", only: :landing
  layout "dashboard", only: :dashboard

  def landing
  end

  def dashboard
  end
end
