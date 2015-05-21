#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'
require 'date'

# require 'colorize'
# require 'pry'
# require 'csv'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

def noko(url)
  Nokogiri::HTML(open(url).read, nil, 'utf-8') 
end

def datefrom(date)
  Date.parse(date)
end

class String
  def trim
    self.gsub(/[[:space:]]/,' ').strip
  end
end
    

@BASE = 'http://www.dna.sr'
@URL = @BASE + '/het-politiek-college/leden/'

page = noko(@URL)
added = 0

page.css('div#maincolumn ul li').each do |mp|
  mp_url = mp.css('h3 a/@href').text
  (faction, faction_id) = mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Fractie")]]/following-sibling::td').text.trim.match(/(.*?)\s+\((.*?)\)/).captures
  (party, party_id) = mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Partij")]]/following-sibling::td/a/@title').text.trim.match(/(.*?)\s+\((.*?)\)/).captures

  data = { 
    id: mp_url.split('/').last,
    name: mp.css('h3').text.split('|').first.gsub(/[[:space:]]/,' ').strip,
    image: mp.css('img/@src').first.text,
    party: party,
    party_id: party_id,
    faction: faction,
    faction_id: faction_id,
    district: mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Kiesdistrict")]]/following-sibling::td').text.gsub(/[[:space:]]/,' ').strip,
    phone: mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Telefoon")]]/following-sibling::td').text.gsub(/[[:space:]]/,' ').strip,
    email: mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Email")]]/following-sibling::td').text.split('/').first.strip,
    term: 2010,
    homepage: mp_url,
    source: @URL,
  }
  image.prepend @BASE unless @image.nil? or @image.empty?
  puts data
  added += 1
  ScraperWiki.save_sqlite([:name, :term], data)
end
puts "  Added #{added} members"


