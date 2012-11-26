class WargamesController < ApplicationController
  skip_before_filter :set_session

  WARGAMES = [
    ['blowfish', '81'],
    ['amateria', '89'],
    ['blackbox', '85'],
    ['apfel', '83'],
    ['logic', '88'],
    ['tux', '86']
  ]

  WARGAMES.each{|game,port| define_method(game){ params.merge!({wargame: game, port: port}) && session[:channel] = "##{game}"}}

  def index
    @wargames = WARGAMES && session[:channel] = "#wargames"
  end

end
