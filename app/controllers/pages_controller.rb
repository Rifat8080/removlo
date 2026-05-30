class PagesController < ApplicationController
  before_action :authenticate_user!, only: :dashboard

  layout :pages_layout

  def landing
  end

  def dashboard
  end

  private

  def pages_layout
    action_name == "dashboard" ? "dashboard" : "landing"
  end
end
