begin
  require "markdown"
rescue LoadError => error
  puts error
end

puts "rdoc-markdown was discovered" if $DEBUG
