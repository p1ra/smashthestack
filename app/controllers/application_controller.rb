class ApplicationController < ActionController::Base
  protect_from_forgery
  respond_to :xml, :json, :text, :html
  helper_method :current_user, :resource_name, :resource, :devise_mapping
  
  def resource_name
    :user
  end
  
  def resource
    @resource ||= User.new
  end
  
  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end
end
