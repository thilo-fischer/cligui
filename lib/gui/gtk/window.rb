#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'

class Window

  DEFAULT_TITLE = "cligui - A Graphical Frontend to Command Line Interfaces"
  DEFAULT_WIDTH = 800
  DEFAULT_HEIGHT = 600
  
  private def widgets
    @widgets ||= {
      :self => Gtk::VBox.new,
      :setup => Proc.new { raise "Child classes of Window shall override the `widgets' method (#{self})." },
    }
  end

  def initialize(title = DEFAULT_TITLE, width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT)
    @window = Gtk::Window.new(title) 
    @window.resizable = true
    @window.border_width = 10 
    @window.signal_connect('destroy') { Gtk.main_quit } # FIXME suppress subsequent dialogs
    @window.set_size_request(width, height)
    install_widgets(@window)
  end

  def install_widgets(container, wgts = widgets)
    packed = FALSE
    current = wgts[:self]
    #$l.debug "packing #{current} into #{container}"
    wgts.each_pair do |key, value|
       case key
       when :self
        # skip
       when :packing
        value.yield(container, current)
        packed = TRUE
       when :signals
        value.each_pair do |signame, proc|
            current.signal_connect(signame) { |arg| proc.yield(arg) }
        end
       else
         case value
         when Hash
           $l.debug "pack #{key} #{value[:self]} into #{current}"
           install_widgets(current, value)
         when Proc
           #$l.trace "yield #{key} #{value}"
           value.yield(current)
         when Gtk::Widget
           #$l.trace "adding #{key} #{value} to #{current}"
           current.add(value) 
         else
           raise "Don't know how to handle " + value.inspect
         end
       end
    end
    if not packed
        container.add(current)
    end
  end

  def show
    $l.debug "@window.show_all (#{caller[0]})"
    @window.show_all
    Gtk.main
  end # show

end # class Window
