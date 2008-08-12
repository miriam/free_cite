class Notifier < ActionMailer::Base
  
  def feedback(p)
    RAILS_DEFAULT_LOGGER.debug "sending feedback from #{p[:email]}\n#{p[:description]}"
    recipients "reftagger.feedback@pubdisplay.com"
    from p[:email]
    subject "RefTagger User Feedback [#{Time.now.to_i}]"
    content_type "text/html"
    body :p => p
    RAILS_DEFAULT_LOGGER.debug "finished sending"
  end

  def recipients(*addrs)
    return super if addrs.empty?
    mr = defined?(MAILER_RECIPIENTS) ? MAILER_RECIPIENTS : nil
    super mr || addrs
  end

end

