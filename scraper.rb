#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MemberName < Scraped::HTML
  field :prefix do
    partitioned.first.join(' ')
  end

  field :suffix do
    partitioned.last.join(' ')
  end

  field :name do
    partitioned[1].join(' ')
  end

  field :gender do
    return 'male' if (prefixes & MALE_PREFIXES).any?
    return 'female' if (prefixes & FEMALE_PREFIXES).any?
  end

  private

  FEMALE_PREFIXES  = %w(mw).freeze
  MALE_PREFIXES    = %w(hr).freeze
  OTHER_PREFIXES   = %w(dr drs ir mr).freeze
  PREFIXES         = FEMALE_PREFIXES + MALE_PREFIXES + OTHER_PREFIXES
  SUFFIXES         = %w(bsc bth bba msc mpa llb).freeze

  def partitioned
    pre, rest = words.partition { |w| PREFIXES.include? w.chomp('.').downcase }
    suf, name = rest.partition { |w| SUFFIXES.include? w.chomp('.').downcase }
    [pre, name, suf]
  end

  def prefixes
    partitioned.first.map { |w| w.chomp('.') }
  end

  def words
    noko.text.split('|').first.tidy.split(/\s+/)
  end
end

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
    name_parts.name
  end

  field :honorific_prefix do
    name_parts.prefix
  end

  field :honorific_suffix do
    name_parts.suffix
  end

  field :gender do
    name_parts.gender
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
    noko.css('.__cf_email__/@data-cfemail').map { |n| parse_cfemail(n.text) }.join(';')
  end

  field :homepage do
    noko.css('h3 a/@href').text
  end

  field :source do
    url
  end

  private

  def name_parts
    fragment(noko.css('h3') => MemberName)
  end

  def faction_data
    noko.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Fractie")]]/following-sibling::td').text.tidy.match(/(.*?)\s+\((.*?)\)/).captures
  end

  def party_data
    noko.at_xpath('.//td[@class="tlabel" and text()[contains(.,"Partij")]]/following-sibling::td/a/@title').text.tidy.match(/(.*?)\s+\((.*?)\)/).captures
  end

  def parse_cfemail(str)
    list = str.scan(/../).map { |str| str.to_i(16) }
    key = list.shift
    list.map { |i| (key ^ i).chr }.join
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
