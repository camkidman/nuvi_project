require "rubygems"
require "zip"
require "redis"
require "nokogiri"
require "open-uri"
require "mechanize"
require "logger"

shortened_url = ARGV[0]
redis_server = ARGV[1]
redis_port = ARGV[2]
redis_password = ARGV[4]
logger = ::Logger.new(STDOUT)

at_exit do
  "Usage: ruby redis_pusher.rb page_url (required) redis_server (optional) redis_port (optional) redis_password (optional)\n"
  "By default, the script will use the REDIS_URL from your environment, pass one in if you'd rather connect to a different redis host"
end

## Do validations here. Argument 1 must be present, default the others to localhost and default port
# Output a "default use" string when no arguments are passed in
#
if shortened_url.nil?
  logger.info("You must pass in a URL for zip files to be pulled from!")
  exit
end

if !redis_server.nil? && redis_server.include?(":")
  unless redis_server.include?("redis://") || redis_server.include?("http")
    logger.info("Please pass the redis port in separately from the host as the second argument")
    exit
  end
end

if !redis_server.nil? && !redis_port.nil?
  redis_server = redis_server.gsub("http://", "")
  if redis_server.include?("redis://")
    redis = redis_password.nil? ? ::Redis.new(:url => redis_server) : ::Redis.new(:url => redis_server, :password => redis_password)
  else
    redis = redis_password.nil? ? ::Redis.new(:host => redis_server, :port => redis_port) : ::Redis.new(:host => redis_server, :port => redis_port, :password => redis_password)
  end
else
  redis = ::Redis.new
end

unless redis.connected?
  logger.error("There was an error connecting to the redis server with the credentials provided. Please check them and try again")
  exit
end

agent = ::Mechanize.new
begin
  source_url = agent.get(shortened_url).uri.to_s
rescue => exception
  logger.error { "URL #{shortened_url} is not available. It's possible the redis host was entered first. If not, please make sure the page loads in a browser" }
  logger.error { "Details: #{exception.inspect}" }
  exit
end

new_item_count = 0
recurring_item_count = 0

source_page = ::Nokogiri::HTML(open(source_url)) do |config|
  config.noblanks
end

zip_links = source_page.css("a").select { |link| link.attribute("href").to_s.include?(".zip") }.map { |node| node.attribute("href").to_s }
logger.info("#{zip_links.count} zip files found")

zip_links.each do |zip_link|
  zip_url = URI.join(source_url, zip_link)
  logger.info("Downloading file #{zip_link} from #{zip_url}")
  begin
    IO.copy_stream(open(zip_url), zip_link)
  rescue ::OpenURI::HTTPError => exception
    logger.error("Http error while trying to download file from #{zip_url}:")
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
          logger.info("The article at URL #{cleansed_article_url} has already been stored!")
          recurring_item_count += 1
          next
        else
          redis.sadd("urls", cleansed_article_url)
          redis.lpush("NEWS_XML", content)
          logger.info("Added one element to NEWS_XML redis list")
          new_item_count += 1
        end
      end
    end
  rescue ::Zip::Error => exception
    logger.error {"Unable to extract zip file #{zip_link}:\n" + exception.inspect }
  end
  ::FileUtils.rm(zip_link) if ::File.exists?(zip_link)
end
logger.info("Added #{new_item_count} articles to the NEWS_XML list")
logger.info("Skipped #{recurring_item_count} articles")
logger.info("Total articles: #{redis.llen("NEWS_XML")}")
