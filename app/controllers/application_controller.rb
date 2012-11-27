class ApplicationController < ActionController::Base
  protect_from_forgery
  respond_to :xml, :json, :text, :html
  helper_method :current_user, :resource_name, :resource, :devise_mapping, :wargames
  before_filter :set_session

  def set_session
    session[:channel] = "#social"
  end

  def resource_name
    :user
  end
  
  def resource
    @resource ||= User.new
  end
  
  def wargames
    @wargames = Wargames::settings
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end
end
