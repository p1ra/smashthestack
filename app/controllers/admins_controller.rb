class AdminsController < ApplicationController
  def index
    @admins = User.admins
  end
end
