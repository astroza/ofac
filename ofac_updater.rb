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
if ENV['APP_ENV']
	APP_ENV = ENV['APP_ENV']
else
	APP_ENV = 'development'
end
INDEX = 'ofac_' + APP_ENV
VINDEX = 'vofac_' + APP_ENV

run_once = ARGV.length > 0
DEBUG = ENV['DEBUG'] != nil

def load_to_elastic_search(doc, source)
  client = Elasticsearch::Client.new log: DEBUG
  
  node = doc.root.child

  begin
    puts "+ Hiding vofac"
    client.indices.delete_alias index: INDEX, name: VINDEX
  rescue
  end
  
  begin
    puts "+ Deleting old entries.. (source:#{source.to_s})"
    client.delete_by_query(index: INDEX, q: 'source:'+source.to_s)
  rescue Elasticsearch::Transport::Transport::Errors::NotFound => not_found
    client.indices.create(:index => INDEX, :body => JSON.parse(File.open('mapping.json') {|f| d=f.read; f.close; d}))
  end
  count = 0
  puts "+ Inserting entries"
  while node
    if node.class != Nokogiri::XML::Text and node.name == 'sdnEntry'
      node_hash = node.to_hash
      node_hash['source'] = source
      client.index(index: INDEX, type: 'entry', body: node_hash)
      if DEBUG
        puts '----------------------------'
      end
      count += 1
    end
    node = node.next
  end
  puts "+ #{count} entries added"
  client.indices.put_alias index: INDEX, name: VINDEX
  puts "+ vofac is available again"
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

update_dates = {}
for xml_url in XMLS
  update_dates[xml_url] = Date.new(0)
end

begin
  File.open(PERSISTENT_UPDATE_DATES, 'r').tap { |f| update_dates=Marshal.load(f.read) }.close if File.exists?(PERSISTENT_UPDATE_DATES)
rescue
  puts 'Ignoring the persisted update dates'
end

puts "index: #{INDEX}, vindex: #{VINDEX}"
if not run_once
	puts "Daemon mode"
end

begin
  XMLS.each_with_index do |xml_url, source|
    response = HTTParty.head(xml_url)
    date = Date.parse(response.headers['last-modified'])
    if date > update_dates[xml_url]
      puts "+ Updating from #{xml_url} (#{date})"
      doc = Nokogiri::XML(open(xml_url)) do |config|
        config.noblanks
      end
      update_dates[xml_url] = date
      load_to_elastic_search(doc, source)
    else
      puts "+ Nothing to do for #{xml_url} (updated #{date})"
    end
  end
  File.open(PERSISTENT_UPDATE_DATES, 'w').tap { |f| f.write(Marshal.dump(update_dates)) }.close
  if not run_once
    sleep UPDATE_INTERVAL
  end
end until run_once
