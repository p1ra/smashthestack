class SessionsController < Devise::SessionsController
  def create
    resource = warden.authenticate!(scope: resource_name, recall: "sessions#failure")
    return sign_in_and_redirect(resource_name, resource)
  end
  
  def sign_in_and_redirect(resource_or_scope, resource=nil)
    scope      = Devise::Mapping.find_scope!(resource_or_scope)
    resource ||= resource_or_scope
    redirect_url = stored_location_for(scope) || after_sign_in_path_for(resource)
    return render json: { success: true, location: redirect_url}
  end
  
  def failure
    return render json: {success: false, error: "Login failed."}
  end
end
