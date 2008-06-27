#!/usr/bin/env ruby
#
# Simple implementation of regression tests for xml generated by parse-speeches.rb
# N.B. Need to pre-populate reference xml files with those that have previously been generated.
# In other words, this is only useful for checking that any refactoring has not caused a regression in behaviour.
#

$:.unshift "#{File.dirname(__FILE__)}/../lib"

require 'people'
require 'hansard_parser'
require 'configuration'

# Range of dates to test

from_date = Date.new(2006, 1, 1)
to_date = Date.new(2008, 6, 1)

# Number of items to skip at the beginning
skip = 0

# Dates to test first before anything else
# Update this list with any dates that have shown up problems in the past

test_first = [Date.new(2007,8,8), Date.new(2008,3,12)]

skip_dates = []

#

conf = Configuration.new

# First load people back in so that we can look up member id's
people = People.read_members_csv("#{File.dirname(__FILE__)}/../data/people.csv", "#{File.dirname(__FILE__)}/../data/members.csv")

parser = HansardParser.new(people)

def test_date(date, conf, parser)
  xml_filename = "debates#{date}.xml"
  new_xml_path = "#{conf.xml_path}/scrapedxml/debates/#{xml_filename}"
  ref_xml_path = "#{File.dirname(__FILE__)}/ref/#{xml_filename}"
  parser.parse_date(date, new_xml_path)
  
  if File.exists?(ref_xml_path) && File.exists?(new_xml_path)
    # Now compare generated and reference xml
    command = "diff #{new_xml_path} #{ref_xml_path}"
    puts command
    system(command)
    if $? != 0
      test = "regression_failed_text.xml"
      ref = "regression_failed_ref.xml"
      #system("rm -f #{test} #{ref}")
      system("tidy -xml -o #{test} #{new_xml_path}")
      system("tidy -xml -o #{ref} #{ref_xml_path}")
      system("opendiff #{test} #{ref}")
      puts "ERROR: #{new_xml_path} and #{ref_xml_path} don't match"
      puts "Regression tests FAILED on date #{date}!"
      exit
    end
  elsif File.exists?(ref_xml_path)
    puts "ERROR: #{new_xml_path} is missing"
    puts "Regression tests FAILED on date #{date}!"
    exit
  elsif File.exists?(new_xml_path)
    puts "ERROR: #{ref_xml_path} is missing"
    puts "Regression tests FAILED on date #{date}!"
    exit
  end
end

class Array
  def randomly_permute
    temp = clone
    result = []
    (1..size).each do
      i = rand(temp.size)
      result << temp[i]
      temp.delete_at(i)
    end
    result
  end
end

# Randomly permute array. This means that we will cover a much broader range of dates quickly
srand(42)
dates = (from_date..to_date).to_a.randomly_permute

test_first.each do |date|
  # Moves date to the beginning of the array
  dates.delete(date)
  dates.unshift(date)
end

skip_dates.each { |date| dates.delete(date) }

count = skip
time0 = Time.new
dates[skip..-1].each do |date|
  test_date(date, conf, parser)
  count = count + 1
  puts "Regression test progress: Done #{count}/#{dates.size}"
  seconds_left = ((Time.new - time0) / count * (dates.size - count)).to_i
  
  minutes_left = (seconds_left / 60).to_i
  seconds_left = seconds_left - 60 * minutes_left
  
  hours_left = (minutes_left / 60).to_i
  minutes_left = minutes_left - 60 * hours_left
  
  if hours_left > 0
    puts "Estimated time left to completion: #{hours_left} hours #{minutes_left} mins"
  else
    puts "Estimated time left to completion: #{minutes_left} mins #{seconds_left} secs"
  end
end

puts "Regression tests all passed!"
