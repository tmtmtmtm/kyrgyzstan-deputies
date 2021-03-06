#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :members do
    noko.xpath('//table[@class="table"]//tr[td]').map do |tr|
      fragment tr => MemberRow
    end
  end

  class MemberRow < Scraped::HTML
    field :number do
      tds[0].text.tidy
    end

    field :id do
      url.split('/')[-2]
    end

    field :name do
      tds[1].text.tidy
    end

    field :url do
      tds[1].css('a/@href').text
    end

    field :faction do
      tds[2].text.tidy
    end

    field :faction_url do
      tds[2].css('a/@href').text
    end

    field :faction_id do
      faction_url.split('/')[-3]
    end

    private

    def tds
      noko.css('td')
    end
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :id do
    url.to_s.split('/')[-2]
  end

  field :name do
    noko.css('p.person-name').text.tidy
  end

  field :faction do
    noko.css('p.person-support').text.tidy
  end

  field :image do
    noko.css('.person-img img/@src').text
  end

  field :term do
    '6'
  end

  field :phone do
    infotable.xpath('.//th[.="Телефон:"]//following-sibling::td').text
  end

  field :source do
    url.to_s
  end

  private

  def infotable
    noko.css('table.person-inform-table')
  end
end

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

kg = (scrape 'http://www.kenesh.kg/ky/deputy/list/35' => MembersPage).members
ru = (scrape 'http://www.kenesh.kg/ru/deputy/list/35' => MembersPage).members

factions = kg.map(&:to_h).map { |m| [m[:faction], m[:faction_id]] }.to_h
ru_names = ru.map { |m| [m.id, m.name] }.to_h

data = kg.map { |mem| scrape mem.url => MemberPage }.map(&:to_h)
data.each do |m|
  m[:name__kg]   = m[:name]
  m[:name__ru]   = ru_names[m[:id]]
  m[:faction_id] = factions[m[:faction]]
end

# puts data
ScraperWiki.save_sqlite(%i[id term], data)
