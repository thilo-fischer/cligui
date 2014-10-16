#!/usr/bin/env ruby

=begin
  help_to_clidef.rb - Tool to create cligui cli-definition file stubs from a commands' help output.

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

#require '...'
require 'rexml/element'
require 'rexml/document'
require 'logger'

$l = Logger.new(STDOUT)
if $DEBUG
  $l.level = Logger::DEBUG
  $l.datetime_format = '%Y-%m-%d %H:%M:%S'
  $l.formatter = proc do |severity, datetime, progname, msg| "#{datetime} #{severity} #{msg}\n" end
else
  $l.level = Logger::INFO
  $l.datetime_format = ''
  $l.formatter = proc do |severity, datetime, progname, msg| "#{severity} #{msg}\n" end
end

# FIXME is document necessary?
doc = REXML::Document.new("<category></category>")
$root = doc.root

command = ARGV.join(" ")
lines = `#{command}`.lines

class StatePostOptions; end
class StateParseOptions < StatePostOptions; end
class StateExpectDescription < StateParseOptions; end
class StateExpectUsage < StateExpectDescription; end

class StateExpectUsage < StateExpectDescription
  REGEXP = /^Usage:\s+(\w+)\s+(.*)$/
  def self.parse_line(ln)
    $l.debug "*** #{self.to_s}.parse_line(\"#{ln}\")"
    if ln =~ REGEXP
      $l.debug "  * #{Regexp.last_match.inspect}"
      executable = Regexp.last_match(1)
      $l.warn "warning ..." if executable != ARGV[0]
      e = $root.add_element("title")
      e.text = executable
      e = $root.add_element("executable")
      e.text = ARGV[0]

      # add description element already now to make it appaer at the beginning of the XML code (just after "executable")
      e = $root.add_element("description")
      e.text = ""

      # TODO handle stuff like `[[foo] bar]'
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
          e.text = ""
        else
          $l.warn "warning ..."
        end
      end
      StateExpectDescription
    else
      superstate = superclass.parse_line(ln)
      if superstate == StateParseOptions
        StateParseOptions
      else
        self
      end
    end
  end
end # class StateExpectUsage 

class StateExpectDescription < StateParseOptions
  def self.parse_line(ln)
    $l.debug "*** 01 #{self.to_s}.parse_line(\"#{ln}\")"
 if ln !~ superclass::REGEXP
      $l.debug "  * desc #{Regexp.last_match.inspect}"
      e = $root.elements["description"]
      e.add_text ln
      self
    else
      $l.debug "  * opts #{Regexp.last_match.inspect}"
      superclass.parse_line(ln)
    end
  end
end

class StateParseOptions < StatePostOptions
  REGEXP = /^\s*(-[\w\-]+(?:(?:\s+|\s*,\s*)-[\w\-]+)*)(\[?=[\w\-\.,:]+\]?\s+)?(.*?)$/
  def self.parse_line(ln)
    $l.debug "*** 02 #{self.to_s}.parse_line(\"#{ln}\")"
    # assume options are always the first thing after the command name in the "Usage: ..." line
    unless @opt_section_e
      @opt_section_e   = $root.elements["section"]
      @opt_section_e ||= $root.add_element("section", {"title"=>"options"})
    end
    if ln =~ REGEXP
      $l.debug "  * #{Regexp.last_match.inspect}"
      names    = Regexp.last_match(1)
      flag_arg = Regexp.last_match(2)
      desc     = Regexp.last_match(3)
      if flag_arg
        e = @opt_section_e.add_element("flag")
      else
        e = @opt_section_e.add_element("switch")
      end
      names.split(/\s+|\s*,\s*/).each do |name|
        if name =~ /^-\w$/
          n = e.add_element("shortname")
        else
          n = e.add_element("longname")
        end
        n.text = name
      end

      d = e.add_element("description")
      d.text = desc

      if flag_arg
        flag_arg =~ /(\[)?=(.*?)\]?\s*$/
        count = Regexp.last_match(1) ? "0..1" : "1"
        title = Regexp.last_match(2)
        sect = e.add_element("section", {"title"=>title,"count"=>count})
        sect.text = ""
      end

      @recent_e = e

      self
    elsif ln =~ /^\s+/
      # append to desription of most recent option
      # TODO keep line breakes in .xml output
      @recent_e.elements["description"].add_text(ln)
      self
    else
      super
    end
  end
end

class StatePostOptions
  def self.parse_line(ln)
    $l.debug "*** 03 #{self.to_s}.parse_line(\"#{ln}\")"
    e = $root.elements["description"]
    e.add_text ln
    self
  end
end

state = StateExpectUsage

until lines.empty? do
  ln = lines.shift.chomp
  $l.debug "* #{state.to_s} << \"#{ln}\""
  state = state.parse_line(ln)
end

$root.write(STDOUT, 2)
STDOUT.puts

