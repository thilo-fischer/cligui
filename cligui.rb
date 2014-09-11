=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'logger'

require_relative 'clidef'
require_relative 'gui'

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

clidef_tree = ClidefTree.new("./cli-definitions")

#selwin = SelectionWindow.new(clidef_tree.root)
#clidef = selwin.show
$l.debug "#{clidef_tree}"
$l.debug "#{clidef_tree.root}"
$l.debug "#{clidef_tree.root.get_children}"
$l.debug "#{clidef_tree.root.get_children[0]}"
$l.debug "#{clidef_tree.root.get_children[0].get_children}"
$l.debug "#{clidef_tree.root.get_children[0].get_children[0]}"
clidef = clidef_tree.root.get_children[0].get_children[0] # for debugging CommandWindow

cmdwin = CommandWindow.new(clidef)
cmdline = cmdwin.show

execwin = ExecWindow.new(cmdline)
execwin.show
