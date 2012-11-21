class RegistrationsController < Devise::RegistrationsController
  prepend_before_filter :require_no_authentication, :only => [ :new, :create, :cancel ]
  
  def new
    resource = build_resource({})
    respond_with resource
  end

  def create
    build_resource
    if resource.save
      if resource.active_for_authentication? 
        set_flash_message :notice, :signed_up if is_navigational_format?
        sign_up(resource_name, resource)
        return render json: {success: true, user: resource, location: after_sign_up_path_for(resource)} 
      else
        set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_navigational_format?
        expire_session_data_after_sign_in!
        respond_with resource, :location => after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      return render json: { success: false, error: 'Registration failed.' } if request.xhr?
      respond_with resource 
    end
  end
  def sign_up(resource_name, resource)
    sign_in(resource_name, resource)
  end
end
