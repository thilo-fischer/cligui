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
    $l.debug "packing #{current} into #{container}"
    wgts.each_pair do |key, value|
       case key
       when :self
        # skip
       when :packing
        value.yield(container, current)
        packed = TRUE
       when :signals
        value.each_pair do |key, value|
            current.signal_connect(key) { |arg| value.yield(arg) }
        end
       else
         case value
         when Hash
           $l.debug "pack #{key} #{value[:self]} from #{value} into #{current}"
           pack_widgets(current, value)
         when Proc
           $l.debug "yield #{key} #{value}"
           value.yield(current)
         when Gtk::Widget
           $l.debug "adding #{key} #{value} to #{current}"
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
    $l.debug "add to treestore: " + clidef.title
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
          :setup => Proc.new do |w|
              w.text = @clidef.title
          end,
      },
      :description => {
          :self => Gtk::Label.new,
          :setup => Proc.new do |w|
              w.text = @clidef.description
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
        f = Gtk::Frame.new(s.title)
        b = Gtk::ToggleButton.new
        b.add(f)
        @button_section_map[b] = s
        @cmd_box.pack_start(b)
        b.signal_connect('toggled') do |b|
          # FIXME toggled will be signaled to button also when calling active=, so two buttons will receive the toggled signal when "switching" activity from one button to another
          puts "#{b} toggled"
          if b.active?
            @current_button.active = FALSE if @current_button
            @current_button = b
          else
            raise "Invalid state" unless @current_button == b
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
      display_frame = @current_button.children[0]
      section.render(@argedit_box, @help_text, display_frame)
    else
      @help_text.text = TEXT_NO_SECTION_SELECTED 
    end
  end

end # class CommandWindow

class SectionRenderer

  def initialize(section, editor_controls, editor_help, display)
    @section = section
    @editor_controls = editor_controls
    @editor_help = editor_help
    @display = display
  end

  def render
    render_editor
  end

  def render_display
  end

  def render_editor
    if @section.element_count == 1
      @section.each_element do |e|
        e.render_editor
      end
    else
      radio_group_button = nil
      if @section.count_min == 1 and @section.count_max == 1
        # TODO use RadioButton instead of CheckButton
        get_button = Proc.new do
          b = Gtk::RadioButton(radio_group_button)
          radio_group_button ||= b
        end
      else
        get_button = Proc.new { Gtk::CheckButton.new }
      end
      @section.each_element do |elem|
        ed = elem.get_render.get_editor
        button = get_button
        button.add(ed)
      end
    end
  end

end # class SectionRenderer

class ElementRenderer

  def initialize(element)
    @element = element
  end

  def get_display
    Gtk::Label(@element.title)
  end
  
  alias get_editor get_display

end # class ElementRenderer


class SwitchRenderer < ElementRenderer
end


class FlagRenderer < ElementRenderer

  def get_display
    frame = Gtk::Frame(@elemet.title)
    section = @element.argument
    renderer = section.renderer(nil, nil, frame) # FIXME
    renderer.render_display
    frame
  end

  def get_display
    frame = Gtk::Frame(@elemet.title)
    section = @element.argument
    renderer = section.renderer(frame, nil, nil) # FIXME
    renderer.render_editor
    frame
  end

end


