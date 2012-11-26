class WargamesController < ApplicationController
  skip_before_filter :set_session

  Wargames::settings.each do |name, status, port, admin|
    define_method(name) do 
      params.merge!({wargame: name, status: status, port: port, admin: admin}) 
      session[:channel] = "##{name}"
      render template: "wargames/#{status}"
    end
  end
  
  def index
    session[:channel] = "#wargames"
  end
end
