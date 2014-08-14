#!/usr/bin/env ruby

=begin
  help_to_clidef.rb - Tool to create cligui cli-definition file stubs from a commands' help output.

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

#require '...'
require 'rexml/element'
require 'rexml/document'

# FIXME is document necessary?
doc = REXML::Document.new("<category></category>")
$root = doc.root

command = ARGV.join(" ")
lines = `#{command}`.lines

class StateParseOptions; end
class StateExpectDescription < StateParseOptions; end
class StateExpectUsage < StateExpectDescription; end

class StateExpectUsage < StateExpectDescription
  REGEXP = /^Usage:\s+(\w+)\s+(.*)$/
  def self.parse_line(ln)
    puts "*** #{self.to_s}.parse_line(\"#{ln}\")"
    if ln =~ REGEXP
      puts "  * #{Regexp.last_match.inspect}"
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
          e.attributes["title"] = arg
          e.attributes["count"] = count
        else
          puts "warning ..."
        end
      end
      StateExpectDescription
    else
      superclass.parse_line(ln)
    end
  end
end # class StateExpectUsage 

class StateExpectDescription < StateParseOptions
  def self.parse_line(ln)
    puts "*** 01 #{self.to_s}.parse_line(\"#{ln}\")"
 if ln !~ superclass::REGEXP
      puts "  * desc #{Regexp.last_match.inspect}"
      e   = $root.elements["description"]
      e ||= $root.add_element("description")
      e.add_text ln
      self
    else
      puts "  * opts #{Regexp.last_match.inspect}"
      superclass.parse_line(ln)
    end
  end
end

class StateParseOptions
  REGEXP = /^\s*((?:-[\w\-]+(?:\s+|\s*[,=]\s*))+)(.*?)$/
  def self.parse_line(ln)
    puts "*** 02 #{self.to_s}.parse_line(\"#{ln}\")"
    # assume options are always the first thing after the command name in the "Usage: ..." line
    unless @opt_section_e
      @opt_section_e   = $root.elements["section"]
      @opt_section_e ||= $root.add_element("section", {"title"=>"options"})
    end
    if ln =~ REGEXP
      puts "  * #{Regexp.last_match.inspect}"
      names = Regexp.last_match(1)
      desc  = Regexp.last_match(2)
      if names =~ /=\s*/
        e = @opt_section_e.add_element("flag")
        flag_arg = desc.slice!(/[\w\-\.:]+(\s+|$)/).rstrip
        sect = e.add_element("section", {"title"=>flag_arg,"count"=>"1"})
        sect.text = ""
      else
        e = @opt_section_e.add_element("switch")
      end
      names.split(/\s+|\s*[,=]\s*/).each do |name|
        if name =~ /^-\w$/
          n = e.add_element("shortname")
        else
          n = e.add_element("longname")
        end
        n.text = name
      end

      d = e.add_element("description")
      d.text = desc
      @recent_e = e
    else
      # append to desription of most recent option
      @recent_e.elements["description"].add_text ln
    end
    self
  end
end

state = StateExpectUsage

until lines.empty? do
  ln = lines.shift.chomp
  puts "* #{state.to_s} << \"#{ln}\""
  state = state.parse_line(ln)
end

$root.write(STDOUT, 2)
STDOUT.puts

