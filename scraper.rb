#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class WikipediaPage < Scraped::HTML
  field :current_composition do
    current_composition_rows.map do |tr|
      fragment tr => MemberRow
    end
  end

  field :previous_composition do
    previous_composition_rows.map do |tr|
      fragment tr => MemberRow
    end
  end

  private

  def current_composition_rows
    noko.xpath('.//h2[contains(.,"Current composition")]/following-sibling::table[1]//tr[td]')
  end

  def previous_composition_rows
    noko.xpath('.//h2[contains(.,"Previous composition")]/following-sibling::table[1]//tr[td]')
  end
end

class MemberRow < Scraped::HTML
  field :id do
    idify(tds[1].css('a'))
  end

  field :name do
    tds[1].text.strip
  end

  field :wikipedia__en do
    tds[1].xpath('a[not(@class="new")]/@title').text.strip
  end

  field :party_id do
    tds[2].children.first.text.strip
  end

  field :party do
    return 'Saint Lucia Labour Party' if party_id == 'SLP'
    return 'United Workers Party' if party_id == 'UWP'
    return 'Independent' if party_id == 'Independent'
    raise "unknown party; #{party_id}"
  end

  field :area do
    area
  end

  field :area_id do
    'ocd-division/country:lc/constituency:%s' % area.downcase.tr(' ', '-')
  end

  field :source do
    url
  end

  private

  def tds
    noko.css('td')
  end

  def area
    tds[0].text.strip
  end

  def idify(a)
    name = a.xpath('./@class').text == 'new' ? a.text : a.attr('title').value
    name.tr(' ', '-').downcase
  end
end

url = 'https://en.wikipedia.org/wiki/House_of_Assembly_of_Saint_Lucia'
page = WikipediaPage.new(response: Scraped::Request.new(url: url).response)
current = page.current_composition.map { |m| m.to_h.merge(term: 9) }
previous = page.previous_composition.map { |m| m.to_h.merge(term: 8) }

# puts current + previous
ScraperWiki.save_sqlite(%i(id term), current + previous)

