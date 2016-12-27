#!/usr/bin/env ruby

require 'open-uri'
require 'nokogiri'
require 'vcr'

require 'pry'

VCR.configure do |config|
    config.cassette_library_dir = 'vcr_cassettes'
    config.hook_into :webmock
end

# http://champion.gg/statistics/#?roleSort=Support
# をパースしたかったがチャンピオン一覧がscriptとして埋め込まれているので
# やむなくjqueryで抽出したものをコピペ
#
# したものから更に著しく少ないのを除外(理由はfiddlesticks vs galioが過去一度もなかったせいで
# マッチアップページが存在せず取り回しが面倒だから

# TODO あとで改めて追加して、ないものはnilとして取り回すようにする
# SUPPORT_CHAMPIONS = %w!Alistar Annie Bard Blitzcrank Brand Braum FiddleSticks
# Galio Ivern Janna Karma Leona Lulu Lux Morgana Nami Nautilus Nunu Shen Sion
# Sona Soraka TahmKench Taliyah Taric Thresh Velkoz Zilean Zyra!
SUPPORT_CHAMPIONS = %w!Alistar Annie Bard Blitzcrank Brand Braum
Janna Karma Leona Lulu Lux Morgana Nami Nautilus
Sona Soraka TahmKench Taric Thresh Velkoz Zilean Zyra!

def get_doc(url)
  charset = nil
  html = open (url) do |f|
    charset = f.charset
    f.read
  end

  Nokogiri::HTML.parse(html, nil, charset)

end

matchup = Hash.new { |h,k| h[k] = {} }

VCR.use_cassette('search_query',:record => :new_episodes) do
  SUPPORT_CHAMPIONS.each do |from|
    SUPPORT_CHAMPIONS.each do |to|
      next unless from < to
      # champion.ggのマッチアップのページは片方しかない
      # (しかも規則がよくわからん。チャンピオンリリース順?)
      # なので片方やってみて404ならもう片方にアクセスする
      begin
        doc = get_doc("http://champion.gg/matchup/#{from}/#{to}/Support")
        winrate_percent = doc.css('tr:nth-child(1) > td:nth-child(2).matchup-values-width').text
        winrate = winrate_percent.chop.to_f / 100.0
      rescue
        doc = get_doc("http://champion.gg/matchup/#{to}/#{from}/Support")
        winrate_percent = doc.css('tr:nth-child(1) > td:nth-child(2).matchup-values-width').text
        winrate = 1 - winrate_percent.chop.to_f / 100.0
      end
      matchup[from][to] = winrate
      matchup[to][from] = 1 - winrate
    end
  end
end


print ','
print SUPPORT_CHAMPIONS.join(',')
print "\n"
SUPPORT_CHAMPIONS.each do |from|
  print from
  print ','
  SUPPORT_CHAMPIONS.each do |to|
    print matchup[from][to]
    print ','
  end
  print "\n"
end
