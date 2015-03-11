# Felipe Astroza - 2015-03
require 'httparty'
require 'open-uri'
require 'nokogiri'
require 'json'
require 'date'
require 'debugger'
require 'elasticsearch'


PERSISTENT_UPDATE_DATES = '.ofac_update_dates'
XMLS = ['http://www.treasury.gov/ofac/downloads/consolidated/consolidated.xml', 'http://www.treasury.gov/ofac/downloads/sdn.xml']
UPDATE_INTERVAL = 24*60*60

run_once = ARGV.length > 0
DEBUG = ENV['DEBUG'] != nil

def load_to_elastic_search(doc)
  client = Elasticsearch::Client.new log: DEBUG
  
  node = doc.root.child
  puts "+ Deleting index.."
  client.indices.delete(index: 'ofac')
  count = 0
  while node
    if node.class != Nokogiri::XML::Text and node.name == 'sdnEntry'
      
      resp = client.index(index: 'ofac', type: 'entry', body: node.to_hash)
      if DEBUG
        puts resp
        puts '----------------------------'
      end
      count += 1
    end
    node = node.next
  end
  puts "+ #{count} entries added"
end

class Nokogiri::XML::Element
  def to_json(*a)
    to_hash.to_json(*a)
  end
  
  def to_hash
    h = {}
    children.each do |child|
      if child.class == Nokogiri::XML::Text
        return child.text
      end
      h[child.name.to_s] = child.to_hash
    end
    h
  end
end

class Nokogiri::XML::Document
  def to_json(*a)
    root.to_json(*a)
  end
end

class Nokogiri::XML::Text
  def to_json(*a)
    text.to_json(*a)
  end
end

update_dates = {}
for xml_url in XMLS
  update_dates[xml_url] = Date.new(0)
end

begin
  File.open(PERSISTENT_UPDATE_DATES, 'r').tap { |f| update_dates=Marshal.load(f.read) }.close if File.exists?(PERSISTENT_UPDATE_DATES)
rescue
  puts 'Ignoring the persisted update dates'
end

begin
  for xml_url in XMLS
    response = HTTParty.head(xml_url)
    date = Date.parse(response.headers['last-modified'])
    if date > update_dates[xml_url]
      puts "+ Updating from #{xml_url} (#{date})"
      doc = Nokogiri::XML(open(xml_url)) do |config|
        config.noblanks
      end
      update_dates[xml_url] = date
      load_to_elastic_search(doc)
    else
      puts "+ Nothing to do for #{xml_url} (updated #{date})"
    end
  end
  File.open(PERSISTENT_UPDATE_DATES, 'w').tap { |f| f.write(Marshal.dump(update_dates)) }.close
  if not run_once
    sleep UPDATE_INTERVAL
  end
end until run_once
