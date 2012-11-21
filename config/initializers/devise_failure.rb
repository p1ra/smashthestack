class DeviseFailure < Devise::FailureApp
  def http_auth?
    false
  end

  def redirect_url
    send(:"new_#{scope}_session_path", format: (request.xhr? ? 'js' : nil ))
  end
end
