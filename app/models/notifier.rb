class Notifier < ActionMailer::Base
  
  def feedback(p)
    recipients "freecite.feedback@pubdisplay.com"
    from p[:email]
    subject "CiteParse User Feedback [#{Time.now.to_i}]"
    content_type "text/html"
    body :p => p
  end

  def recipients(*addrs)
    return super if addrs.empty?
    mr = defined?(MAILER_RECIPIENTS) ? MAILER_RECIPIENTS : nil
    super mr || addrs
  end

end

