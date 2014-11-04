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
    @editor = new_editor unless @editor
    @editor.show_all
    update_editor_activity
    @editor
  end

  private def new_editor
    trace_methodcall
    Gtk::Label.new(@element.title)
  end

  # no need to update if editor widgets have not yet been created or are not currently being displayed in the GUI
  private def update_editor?
    @editor && @editor.parent
  end

  # Shall be overridden by derived classes. Implementation is very generic, but neither accurate nor efficient.
  def update_editor
    trace_methodcall
    if update_editor?
      parent = @editor.parent
      parent.remove(@editor)
      @editor = new_editor
      parent.add(@editor)
      update_editor_activity
    end
  end

  def update_editor_activity
    trace_methodcall
    if @editor
      @editor.sensitive = @element.active?
    end
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
        container.pack_start(e.renderer.display, false, false)
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

class ArgumentRenderer < ElementRenderer

  private def model
    unless @model
      @model ||= Gtk::ListStore.new(String)
      @element.raw_args.each do |a|
        listitem = @model.append
        listitem[0] = a
      end
      @model.signal_connect("row-changed")  { |model, path, iter| update_element(iter) }
      @model.signal_connect("row-inserted") { |model, path, iter| update_element }
      @model.signal_connect("row-deleted")  { |model, path, iter| update_element }
      @model.signal_connect("rows-reordered") { update_element }
    end
    @model
  end

  private def update_model
    # destroy model and recreate (implementation shortcut ...)
    @model = nil
    model
  end

  # changepos May be provided to specify the row(s) in which the model was updated and to restrict element update for performance reasons to only these items. May be a TreePath, TreeIter, integer number, a range between two of these or an array containing a combination of the beforementioned -- TODO evaluate changepos
  private def update_element(changepos = nil)
    # destroy array and recreate (implementation shortcut ...)
    @element.raw_args = []
    @model.each { |model, path, iter| @element.raw_args << iter[0] }
    @@cmdwindow.update_cmdentry
  end

  private def new_display
    trace_methodcall
    view = Gtk::TreeView.new(model)
    view.headers_visible = false
    view.selection.mode = Gtk::SELECTION_SINGLE
    view.reorderable = true
    cell_renderer = Gtk::CellRendererText.new
    cell_renderer.editable = true
    # TODO incomplete API doc for Gtk::CellRendererText signal edited (only 1 parameter documented)
    cell_renderer.signal_connect("edited") do |renderer, path, new_text|
      iter = @model.get_iter(path)
      iter[0] = new_text
      #update_element(path) => done via signal row-changed
    end
    view.append_column(Gtk::TreeViewColumn.new("Arguments", cell_renderer, :text => 0))
    view
  end

  private def new_editor
    trace_methodcall
    box = Gtk::HBox.new
    view = new_display
    box.pack_start(view, true, true)
    buttons = Gtk::VButtonBox.new
    buttons.layout_style = Gtk::ButtonBox::START
    box.pack_start(buttons, false, false)
    
    addBtn = Gtk::Button.new("+") 
    addBtn.signal_connect("clicked") do
      selected = view.selection.selected
      if selected
        iter = @model.insert_after(selected)
      else
        iter = @model.append
      end
      iter[0] = "new argument"
      view.grab_focus
      view.set_cursor(iter.path, view.get_column(0), true)
    end
    buttons.add(addBtn)
    
    delBtn = Gtk::Button.new("-")
    delBtn.signal_connect("clicked") do
      iter = view.selection.selected
# TODO msgbox if no selection
      @model.remove(iter)
      #update_element => done via signal row-changed
    end
    buttons.add(delBtn)

    rstBtn = Gtk::Button.new("0")
    rstBtn.signal_connect("clicked") do
      @model.clear
      update_element # => necessary? row-deleted callback invoked for all rows?
    end
    buttons.add(rstBtn)

# TODO add arguments from clipboard button

    box
  end

end # ArgumentRenderer
