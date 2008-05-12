class String

  def xml_escape
    gsub(/[&<>'"]/) do | match |
      case match
      when '&' then '&amp;'
      when '<' then '&lt;'
      when '>' then '&gt;'
      when "'" then '&apos;'
      when '"' then '&quote;'
      end
    end
  end

end

