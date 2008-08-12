class WelcomeController < ApplicationController

  def api_instructions
  end

  def index
  end

  def feedback
    RAILS_DEFAULT_LOGGER.debug "test" 
    RAILS_DEFAULT_LOGGER.debug "req: #{request.inspect}"
    if request.xhr?
      if params[:description].blank?
        RAILS_DEFAULT_LOGGER.debug "test2" 
        render :update do |page|
          page.call "displayNotice", "Please enter a description."
        end
      else
        RAILS_DEFAULT_LOGGER.debug "calling notifier!" 
        Notifier::deliver_feedback(params)
        RAILS_DEFAULT_LOGGER.debug "called notifier"
        render :update do |page|
          page.hide "feedback"
          page.show "feedback_thanks"
        end
      end
    end
  end



end
