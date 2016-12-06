require "rubygems"
require "zip"
require "pry"
require "redis"
require "nokogiri"
require "open-uri"

source_url = ARGV[0]
redis_server = ARGV[1]
redis_port = ARGV[2]
redis_username = ARGV[3]
redis_password = ARGV[4]

## Do validations here. Argument 1 must be present, default the others to localhost and default port
# Output a "default use" string when no arguments are passed in
#
if !redis_server.nil? && !redis_port.nil?
  redis_credentials = !redis_username.nil? || !redis_password.nil? ? "#{redis_username}:#{redis_password}" : nil
  redis = ::Redis.new(:url => redis_server, :port => redis_port)
else
  redis = ::Redis.new
end

source_page = ::Nokogiri::HTML(open(source_url)) do |config|
  config.noblanks
end

zip_links = source_page.css("a").select { |link| link.attribute("href").to_s.include?(".zip") }.map { |node| node.attribute("href").to_s }
puts "#{zip_links.count} zip files found"

zip_links.each do |zip_link|
  zip_url = URI.join(source_url, zip_link)
  puts "Downloading file #{zip_link} from #{zip_url}"
  IO.copy_stream(open(zip_url), zip_link)
  ::Zip::File.open(zip_link) do |zip_file|
    zip_file.each do |xml_doc|
      content = xml_doc.get_input_stream.read
      # Check on what criteria in the redis list? Iterative?
    end
  end
end
