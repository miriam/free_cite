class WelcomeController < ApplicationController
  layout "main"

  def api_instructions
  end

  def index
  end

  def feedback
    if request.xhr?
      if params[:description].blank?
        render :update do |page|
          page.call "displayNotice", "Please enter a description."
        end
      else
        Notifier::deliver_feedback(params)
        render :update do |page|
          page.hide "feedback"
          page.show "feedback_thanks"
        end
      end
    end
  end



end
