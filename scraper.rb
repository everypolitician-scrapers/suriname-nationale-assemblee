#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :members do
    noko.css('div#maincolumn ul li').map do |li|
      fragment(li => MemberItem).to_h
    end
  end

  # We need to override core `noko` to supply the arguments
  # TODO: make this a template method upstream
  def noko
    @noko ||= Nokogiri::HTML(response.body, nil, 'utf-8')
  end
end

class MemberItem < Scraped::HTML
  field :id do
    homepage.split('/').last
  end

  field :name do
    noko.css('h3').text.split('|').first.tidy
  end

  field :gender do
    gender_from(name)
  end

  field :image do
    noko.css('img/@src').first.text
  end

  field :party do
    party_data.first
  end

  field :party_id do
    party_data.last
  end

  field :faction do
    faction_data.first
  end

  field :faction_id do
    faction_data.last
  end

  field :district do
    noko.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Kiesdistrict")]]/following-sibling::td').text.to_s.tidy
  end

  field :phone do
    noko.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Telefoon")]]/following-sibling::td').text.to_s.tidy
  end

  field :email do
    noko.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Email")]]/following-sibling::td').text.split('/').first.to_s.strip
  end

  field :homepage do
    noko.css('h3 a/@href').text
  end

  field :source do
    url
  end

  private

  def faction_data
    noko.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Fractie")]]/following-sibling::td').text.tidy.match(/(.*?)\s+\((.*?)\)/).captures
  end

  def party_data
    noko.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Partij")]]/following-sibling::td/a/@title').text.tidy.match(/(.*?)\s+\((.*?)\)/).captures
  end

  def gender_from(str)
    return 'male' if str.start_with? 'Hr.'
    return 'female' if str.start_with? 'Mw.'
    warn "Unknown gender for #{str}"
    nil
  end
end

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

start = 'http://www.dna.sr/het-politiek-college/leden/'
data = scraper(start => MembersPage).members.map do |member|
  member.merge(term: 2015)
end
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id term], data)
