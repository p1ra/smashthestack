class HomesController < ApplicationController
  def show
    @affiliates = get_affiliates
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

