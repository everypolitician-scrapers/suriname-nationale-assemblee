#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

def noko(url)
  Nokogiri::HTML(open(url).read, nil, 'utf-8')
end

def datefrom(date)
  Date.parse(date)
end

def gender_from(str)
  return 'male' if str.start_with? 'Hr.'
  return 'female' if str.start_with? 'Mw.'
  warn "Unknown gender for #{str}"
  nil
end

@BASE = 'http://www.dna.sr'
@URL = @BASE + '/het-politiek-college/leden/'

page = noko(@URL)
added = 0

page.css('div#maincolumn ul li').each do |mp|
  mp_url = mp.css('h3 a/@href').text
  (faction, faction_id) = mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Fractie")]]/following-sibling::td').text.tidy.match(/(.*?)\s+\((.*?)\)/).captures
  (party, party_id) = mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Partij")]]/following-sibling::td/a/@title').text.tidy.match(/(.*?)\s+\((.*?)\)/).captures

  data = {
    id:         mp_url.split('/').last,
    name:       mp.css('h3').text.split('|').first.tidy,
    image:      mp.css('img/@src').first.text,
    party:      party,
    party_id:   party_id,
    faction:    faction,
    faction_id: faction_id,
    district:   mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Kiesdistrict")]]/following-sibling::td').text.to_s.tidy,
    phone:      mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Telefoon")]]/following-sibling::td').text.to_s.tidy,
    email:      mp.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Email")]]/following-sibling::td').text.split('/').first.to_s.strip,
    term:       2015,
    homepage:   mp_url,
    source:     @URL,
  }
  data[:gender] = gender_from(data[:name])
  data[:image].prepend @BASE unless data[:image].nil? || data[:image].empty?
  added += 1
  ScraperWiki.save_sqlite(%i[name term], data)
end
puts "  Added #{added} members"
