host = case Rails.env
       when 'development' then 'localhost:3000'
       end
ActionMailer::Base.default_url_options = { :host => host }
