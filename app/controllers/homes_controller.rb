class HomesController < ApplicationController
  skip_before_filter :set_session, only: [:irc]
  
  def show
    @affiliates = get_affiliates
    @wargames = Wargames::settings
  end

  def irc
  end

  def faq
  end

  private
  def get_affiliates(files=[])
    filenames = Dir.glob("app/assets/images/affiliates/*").shuffle.reject{|file| /php/.match file}
    filenames.each{|file| files << "/assets/affiliates/#{File.basename(file)}"} 
    files
  end
end

