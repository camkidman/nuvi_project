require "rubygems"
require "zip"
require "pry"
require "redis"
require "nokogiri"
require "open-uri"
require "mechanize"

shortened_url = ARGV[0]
redis_server = ARGV[1]
redis_port = ARGV[2]
redis_username = ARGV[3]
redis_password = ARGV[4]

agent = ::Mechanize.new
source_url = agent.get(shortened_url).uri.to_s
new_item_count = 0
recurring_item_count = 0

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
  begin
    IO.copy_stream(open(zip_url), zip_link)
  rescue ::OpenURI::HTTPError => exception
    puts "Http error while trying to download file from #{zip_url}:"
    exception.inspect
  end

  begin
    ::Zip::File.open(zip_link) do |zip_file|
      zip_file.each do |xml_doc|
        content = xml_doc.get_input_stream.read
        noko_xml = ::Nokogiri::XML(content)
        article_url = noko_xml.xpath("//topic_url/text()").to_s # Get the topic_url as a string
        cleansed_article_url = article_url.gsub(/\?(.*)/, "") # Filter out any reference parameters
        if redis.sismember("urls", cleansed_article_url)
          puts "The article at this URL has already been stored!"
          recurring_item_count += 1
          next
        else
          redis.sadd("urls", cleansed_article_url)
          redis.lpush("NEWS_XML", content)
          puts "Added one element to NEWS_XML redis list"
          new_item_count += 1
        end
      end
    end
  rescue ::Zip::Error => exception
    puts "Unable to extract zip file #{zip_link}:"
    exception.inspect
  ensure
    ::FileUtils.rm(zip_link)
  end
end
puts "Added #{new_item_count} articles to the NEWS_XML list"
puts "Skipped #{recurring_item_count} articles"
puts "Total articles: #{redis.llen("NEWS_XML")}"
