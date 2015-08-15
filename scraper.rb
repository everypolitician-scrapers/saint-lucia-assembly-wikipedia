#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'uri'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def party_id_for(party)
  return 'Saint Lucia Labour Party' if party == 'SLP'
  return 'United Workers Party' if party == 'UWP'
  return 'Independent' if party == 'Independent'
  raise "unknown party; #{party}"
end

def idify(a)
  name = a.xpath('./@class').text == 'new' ? a.text : a.attr('title').value
  name.tr(' ','-').downcase
end

def scrape(url)
  noko = noko_for(url)

  rowdata = ->(tr, term) { 
    tds = tr.css('td')
    data = { 
      id: idify(tds[1].css('a')),
      name: tds[1].text.strip,
      wikipedia__en: tds[1].xpath('a[not(@class="new")]/@title').text.strip,
      party: tds[2].children.first.text.strip,
      party_id: '',
      term: term,
      source: url,
    }
    data[:party_id] = party_id_for(data[:party])
    data
  }

  current = noko.xpath('.//h2[contains(.,"Current composition")]/following-sibling::table[1]//tr[td]').map do |row|
    rowdata.(row, 9)
  end

  previous = noko.xpath('.//h2[contains(.,"Previous composition")]/following-sibling::table[1]//tr[td]').map do |row|
    rowdata.(row, 8)
  end

  ScraperWiki.save_sqlite([:id, :term], current + previous)
end

scrape('https://en.wikipedia.org/wiki/House_of_Assembly_of_Saint_Lucia')
