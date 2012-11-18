class UsersController < ApplicationController
  def create 
    @user = User.create params[:user]
    redirect_to :back
  end
end
