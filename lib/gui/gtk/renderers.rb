#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'

class ElementRenderer

  # Create an object to handle the presentation of element within the GUI.
  def initialize(element)
    $l.debug("initialize #{self} for #{element}")
    @element = element
    @editor = nil
    @display = nil
  end

  def trace_methodcall
    $l.debug "#{caller[0]} invoked at #{self} to render #{@element}:#{@element.title} (#{if @element.active? then "active" else "inactive" end})"
  end

  # The widget (often a container filled with other widgets) displaying the element's current settings.
  # Create the widget if not yet existing.
  def display
    trace_methodcall
    unless @display
      @display = new_display
      @display.show_all
      @display.no_show_all = true # FIXME
    end
    update_display_activity
    @display
  end

  private def new_display
    trace_methodcall
    Gtk::Label.new(@element.title)
  end

  # Shall be overridden by derived classes. Implementation is very generic, but neither accurate nor efficient.
  def update_display
    trace_methodcall
    parent = @display.parent
    parent.remove(@display)
    @display = new_display
    parent.add(@display)
    update_display_activity
  end

  def update_display_activity
    trace_methodcall
    # FIXME
    @display.visible = @element.active?
#if @element.active?
#@display.show_all
#else
#@display.hide_all
#end
  end

  # Update and return the widget (often a container filled with other widgets) to modify the element's settings.
  def editor
    trace_methodcall
    unless @editor
      @editor = new_editor
    end
    @editor.show_all
    update_editor_activity
    @editor
  end

  private def new_editor
    trace_methodcall
    Gtk::Label.new(@element.title)
  end

  # Shall be overridden by derived classes. Implementation is very generic, but neither accurate nor efficient.
  def update_editor
    trace_methodcall
    parent = @editor.parent
    parent.remove(@editor)
    @editor = new_editor
    parent.add(@editor)
    update_editor_activity
  end

  def update_editor_activity
    trace_methodcall
    @editor.sensitive = @element.active?
  end

  def update
    trace_methodcall
    update_display
    update_editor
  end

  def update_activity
    trace_methodcall
    update_display_activity
    update_editor_activity
  end

  def self.cmdwindow=(w)
    @@cmdwindow = w
  end

  def self.cmdwindow # FIXME child classes use @@cmdwindow directly
    @@cmdwindow
  end

end # class ElementRenderer

class SectionRenderer < ElementRenderer

  private def new_display
    trace_methodcall
    if @element.single_element?
      e = @element.first_element
      e.renderer.display
    else
      container = Gtk::VBox.new
      @element.each_element do |e|
        container.add(e.renderer.display)
      end
      container
    end
  end
  
  private def new_editor
    trace_methodcall
    if @element.single_element?
      e = @element.first_element
      e.renderer.editor
    else
      container = Gtk::VBox.new
      radio_group_button = nil
      if @element.count_min == 1 and @element.count_max == 1
        get_button = Proc.new do
          b = Gtk::RadioButton.new(radio_group_button)
          radio_group_button ||= b
          b
        end
      else
        get_button = Proc.new { Gtk::CheckButton.new }
      end
      @element.each_element do |e|
        button = get_button.call
        $l.debug("adding #{e} ...")
        $l.debug("adding #{e} as #{e.renderer.editor} to #{container} of #{@element}")
        button.add(e.renderer.editor)
        container.add(button)
        button.signal_connect('clicked') do |b|
          e.active = b.active?
          e.renderer.update_activity
          @@cmdwindow.update_cmdentry
        end
        button.signal_connect('focus') { @@cmdwindow.helptext = e.helptext }
      end
      container
    end
  end

end # class SectionRenderer

class SwitchRenderer < ElementRenderer

  def update_display
    trace_methodcall
    update_display_activity
  end

  def update_editor
    trace_methodcall
    nil
  end

  def update_editor_activity
    trace_methodcall
    nil
  end

end # SwitchRenderer


class FlagRenderer < ElementRenderer

  private def new_display
    trace_methodcall
    frame = Gtk::Frame.new(@element.title)
    frame.add(@element.argument.renderer.display)
    frame
  end

  def update_display
    trace_methodcall
    update_display_activity
    @element.argument.renderer.update_display
  end

  def update_display_activity
    super
    @element.argument.renderer.update_display_activity
  end

  private def new_editor
    trace_methodcall
    frame = Gtk::Frame.new(@element.title)
    frame.add(@element.argument.renderer.editor)
    frame
  end

  def update_editor
    trace_methodcall
    update_editor_activity
    @element.argument.renderer.update_editor
  end

  def update_editor_activity
    super
    @element.argument.renderer.update_editor_activity
  end

end # FlagRenderer

