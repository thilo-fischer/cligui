#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'

class CliDef; end

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
    pack_widgets(@window)
  end

  def pack_widgets(container, wgts = widgets)
    packed = FALSE
    current = wgts[:self]
    #$l.trace "packing #{current} into #{container}"
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
           #$l.trace "pack #{key} #{value[:self]} from #{value} into #{current}"
           pack_widgets(current, value)
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

class SelectionWindow < Window

  TITLE_IDX = 0
  DESC_IDX  = 1
  REF_IDX  = 2

  private def widgets
    @widgets ||= {
      :self => Gtk::VBox.new,
      :scrolled_win => {
          :self => Gtk::ScrolledWindow.new,
          :setup => Proc.new do |scrolled_win|
              scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
          end,
          :treeview => {
              :self => Gtk::TreeView.new,
              :signals => {
                  'cursor-changed' => Proc.new do |w|
                      puts "cursor-changed"
                      if w.selection.selected
                          @nextBtn.sensitive = w.selection.selected[REF_IDX].respond_to? :run_command
                      end
                  end,
                  'row-activated' => Proc.new do |w|
                      puts "treeview row-activated"
                      @nextBtn.sensitive = w.selection.selected[REF_IDX].respond_to? :run_command
                  end,
              },
              :setup => Proc.new do |treeview|
                  setup_tree_view(treeview)
                  treeview.model = @treestore
                  @treeview = treeview
              end,
          },
      },
      :btnbox => {
          :self => Gtk::HBox.new,
          :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
          :cancel => {
              :self => Gtk::Button.new('Cancel'),
              :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
              :signals => {
                  'clicked' => Proc.new { Gtk.main_quit }, # FIXME suppress subsequent dialogs
              },
          },
          :next => {
              :self => Gtk::Button.new('Next'),
              :packing => Proc.new { |c, w| c.pack_end(w, FALSE, FALSE) },
              :signals => {
                  'clicked' => Proc.new do
                      @selection = @treeview.selection.selected[REF_IDX]
                      Gtk.main_quit # FIXME something like @window.close
                  end,
              },
              :setup => Proc.new do |btn|
                  @nextBtn = btn
                  btn.sensitive = FALSE
              end,
          },
      },
    }
  end # widgets

  def setup_tree_view(treeview)
    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new("Command", renderer, "text" => TITLE_IDX) # TODO what is `"text" => ...' doing ??
    treeview.append_column(column)
    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new("Description", renderer, "text" => DESC_IDX)
    treeview.append_column(column)
  end
  
  def add_to_treestore(clidef, treestore, ts_iter = nil)
    #$l.trace "add to treestore: " + clidef.title
    ts_iter = treestore.append(ts_iter)
    ts_iter[TITLE_IDX] = clidef.title
    ts_iter[DESC_IDX]  = clidef.description
    ts_iter[REF_IDX]   = clidef
    clidef.each_child { |child| add_to_treestore(child, treestore, ts_iter) }
  end

  def initialize(clidef_root)

    @treestore = Gtk::TreeStore.new(String, String, CliDef)
    clidef_root.each_child { |child| add_to_treestore(child, @treestore) }

    super()

  end # initialize

  def show
    super
    @selection
  end # show

end # class SelectionWindow

class CommandWindow < Window

  TEXT_NO_SECTION_SELECTED = "Click on the boxes above to set up the according options for the command invokation."
  TEXT_SECTION_SELECTED    = "Set the options according to your needs using the controls at the left of this text."

  private def widgets
    @widgets ||= {
      :self => Gtk::VBox.new,
      :title => {
          :self => Gtk::Label.new,
          :packing => Proc.new { |c, w| c.pack_start(w, FALSE, true) },
          :setup => Proc.new do |w|
              w.text = @clidef.title
              w.set_markup("<span size='xx-large'>#{@clidef.title}</span>") # FIXME use set_attributes instead of markup
              w.set_xalign(0.1)
              #w.set_attributes()
          end,
      },
      :description => {
          :self => Gtk::Label.new,
          :packing => Proc.new { |c, w| c.pack_start(w, false, FALSE) },
          :setup => Proc.new do |w|
              w.text = @clidef.description
              w.set_markup("<span size='large'>#{@clidef.description}\n</span>") # FIXME use set_attributes instead of markup
              w.set_xalign(0.2)
              #w.set_attributes()
          end,
      },
      :scrolled_win => {
          :self => Gtk::ScrolledWindow.new,
          :setup => Proc.new do |scrolled_win|
              scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
          end,
          :cmd_box => {
              :self => Gtk::HBox.new,
              :cmd_btn => {
                  :self => Gtk::Button.new(@clidef.executable),
              },
              :setup => Proc.new { |w| @cmd_box = w }
          },
      },
      :argumentbox => {
        :self => Gtk::HBox.new,
        :scrolled_win_edit => {
          :self => Gtk::ScrolledWindow.new,
          :setup => Proc.new do |scrolled_win|
              scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
              @argedit_box = scrolled_win
          end,
        },
        :scrolled_win_help => {
          :self => Gtk::ScrolledWindow.new,
          :setup => Proc.new do |scrolled_win|
              scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
          end,
          :help_text => {
              :self => Gtk::Label.new(TEXT_NO_SECTION_SELECTED),
              :setup => Proc.new { |w| @help_text = w },
          },
        },
      },
      :cmdentry => {
          :self => Gtk::Entry.new,
          :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
          :setup => Proc.new { |w| w.editable = false }, # TODO allow entering text, parse the text entered and update visual command line builder accordingly
      },
      :btnbox => {
          :self => Gtk::HBox.new,
          :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
          :cancel => {
              :self => Gtk::Button.new('Cancel'),
              :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
              :signals => {
                  'clicked' => Proc.new { Gtk.main_quit }, # FIXME suppress subsequent dialogs
              },
          },
          :exec => {
              :self => Gtk::Button.new('Execute'),
              :packing => Proc.new { |c, w| c.pack_end(w, FALSE, FALSE) },
              :signals => {
                  'clicked' => Proc.new do
                      @window.close
                  end,
              },
              :setup => Proc.new do |btn|
                  @execBtn = btn
              end,
          },
      },
    }
  end # widgets
  
  def initialize(clidef)
    @clidef = clidef
    @button_section_map = {}
    @current_button = nil
    super()
    @clidef.each_section do |s|
        $l.debug "pack display button for section `#{s.title}'"
        f = Gtk::Frame.new(s.title)
        b = Gtk::ToggleButton.new
        b.add(f)
        f.add(s.renderer.display)
        @button_section_map[b] = s # FIXME in use ?!
        @cmd_box.pack_start(b)
        b.signal_connect('toggled') do |w|
          # FIXME toggled will be signaled to button also when calling active=, so two buttons will receive the toggled signal when "switching" activity from one button to another
          puts "#{w} toggled"
          if w.active?
            @current_button.active = FALSE if @current_button
            @current_button = w
          else
            raise "Invalid state" unless @current_button == w
            @current_button = nil
          end
          refresh_argumentbox
        end
    end
  end

  def refresh_argumentbox
    if @current_button
      @help_text.text = TEXT_SECTION_SELECTED
      section = @button_section_map[@current_button]
      display_frame = @current_button.children.first
      @argedit_box.each { |child| @argedit_box.remove(child) } # TODO Would it be cheaper to just throw away the argedit_box and create a new one?
      #@argedit_box.add(section.renderer.editor)
      @argedit_box.add_with_viewport(section.renderer.editor) # FIXME
    else
      @help_text.text = TEXT_NO_SECTION_SELECTED 
    end
  end

end # class CommandWindow

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
    #@display.visibe = @element.active?
    if @element.active?
      @display.show_all
    else
      @display.hide_all
    end
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

  def self.set_help_wgt(help_wgt)
    trace_methodcall
    @@help_wgt = help_wgt
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
        end
        button.signal_connect('focus') { @@help_wgt.text = e.help_text }
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

end


class FlagRenderer < ElementRenderer

  private def new_display
    trace_methodcall
    frame = Gtk::Frame.new(@element.title)
    section = @element.argument
    frame.add(section.renderer.display)
    frame
  end

  def update_display
    trace_methodcall
    @element.argument.renderer.update_display
    update_display_activity
  end

  private def new_editor
    trace_methodcall
    frame = Gtk::Frame.new(@element.title)
    section = @element.argument
    frame.add(section.renderer.editor)
    frame
  end

  def update_editor
    trace_methodcall
    @element.argument.renderer.update_editor
    update_editor_activity
  end

  def update_editor_activity
    trace_methodcall
    nil
  end

end

