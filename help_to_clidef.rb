#!/usr/bin/env ruby

=begin
  help_to_clidef.rb - Tool to create cligui cli-definition file stubs from a commands' help output.

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

#require '...'
require 'rexml/document'


$root = Element.new("category")

command = ARGV.join(" ")
lines = `#{command}`.lines

class StateParseOptions; end
class StateExpectDescription < StateParseOptions; end
class StateExpectUsage < StateExpectDescription; end

class StateExpectUsage < StateExpectDescription
  REGEXP = /^Usage:\s+(\w+)\s+(.*)$/
  def self.parse_line(l)
    if l =~ REGEXP
      executable = Regexp.last_match(1)
      puts "warning ..." if executable != ARGV[0]
      e = $root.add_element("title")
      e.text = executable
      e = $root.add_element("executable")
      e.text = ARGV[0]

      arguments = Regexp.last_match(2).split(/\s+/)
      arguments.each do |arg|
        if arg =~ /^(\[)?(.*?)(\.\.\.)?\]?$/
          if Regexp.last_match(1)
            count = "0.."
          else
            count = "1.."
          end
          if Regexp.last_match(3)
            count += "n"
          else
            count += "1"
          end
          count = "1" if count == "1..1"
          e = $root.add_element("section")
          e["title"] = arg
          e["count"] = count
        else
          puts "warning ..."
        end
      end
      StateExpectDescription
    else
      super
    end
  end
end # class StateExpectUsage 

class StateExpectDescription < StateParseOptions
  def self.parse_line(l)
    if l !~ super.class.REGEXP
      de = $root.elements["description"]
      if de
        de.text += l
      else
        e = $root.add_element("description")
        e.text = l
      end
      self
    else
      super
    end
  end
end

class StateParseOptions
  REGEXP = /^\s*((-?\w+)(\s+|\s*,\s*))(.*)$/
  def self.parse_line(l)
    # assume options are always the first thing after the command name in the "Usage: ..." line
    options = $root.elements["section"]
    $root.add_element("section", {"title"=>"options"}) unless options
    if l =~ REGEXP
      e = options.add_element("flag") # todo switch?
      names = Regexp.last_match(2)
      names.split(/\s+|\s*,\s*/).each do |name|
        if name =~ /^-\w$/
          n = e.add_element("shortname")
        else
          n = e.add_element("longname")
        end
        n.text = name
      end
      d = e.add_element("description")
      d.text = Regexp.last_match(4)
    else
      # append to desription of most recent option
      options.elements[-1].elements["description"].text += l
    end
    self
  end
end

state = StateParseUsage

until lines.empty? do
  l = lines.shift
  state = state.parse(l)
end

$root.write(STDOUT)


        
