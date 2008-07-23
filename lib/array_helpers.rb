class Array
  def mean
    (size > 0) ? sum.to_f / size : 0
  end
  
  def stddev
    m = mean
    devsum = inject( 0 ) { |ds,x| ds += (x - m)**2 }
    (size > 0) ? (devsum.to_f / size) ** 0.5 : 0
  end

  def cov(other)
    zip(other).map {|a,b| a*b }.mean - (mean * other.mean)
  end

  def pearson_r(other)
    unless size == other.size
      raise "Vectors must be of same length to calculate pearson_r" 
    end
    devp = stddev * other.stddev
    (devp > 0) ? cov(other) / devp : 0.0
  end

end

