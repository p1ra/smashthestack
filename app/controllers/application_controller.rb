class ApplicationController < ActionController::Base
  protect_from_forgery
  respond_to :xml, :json, :text, :html
  helper_method :current_user
end
