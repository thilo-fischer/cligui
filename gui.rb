#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'

class CliDef; end

class Window

  private def widgets
    @widgets ||= {
      :self => Gtk::VBox.new,
      :setup => Proc.new { raise "Child classes of Window shall override the `widgets' method (#{self})." },
    }
  end

  def initialize(title, width = 800, height = 400)
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
         pack_widgets(current, value)
        when Proc
         value.yield(current)
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
                          @nextBtn.sensitive = w.selection.selected[REF_IDX].respond_to? :get_command_structure
                      end
                  end,
                  'row-activated' => Proc.new do |w|
                      puts "treeview row-activated"
                      @nextBtn.sensitive = w.selection.selected[REF_IDX].respond_to? :get_command_structure
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
                      @window.close
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
    ts_iter = treestore.append(ts_iter)
    ts_iter[TITLE_IDX] = clidef.title
    ts_iter[DESC_IDX]  = clidef.description
    ts_iter[REF_IDX]   = clidef
    clidef.each_child { |child| add_to_treestore(child, treestore, ts_iter) }
  end

  def initialize(clidef_root)

    super("cligui - A Graphical Frontend to Command Line Interfaces")

    @treestore = Gtk::TreeStore.new(String, String, CliDef)
    clidef_root.each_child { |child| add_to_treestore(child, @treestore) }

  end # initialize

  def show
    super
    @selection
  end # show

end # class SelectionWindow

class CommandWindow < Window

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
                  :self => Gtk::Button.new,
                  :setup => Proc.new { |w| w.text = @clidef.executable },
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
              :self => Gtk::Label.new("Click on the boxes above to set up the according options for the command invokation."),
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
    super
    @clidef.each_section do |s|
        w = Gtk::Frame(s.title)
        @frame_section_map[w] = s
        @cmd_box.pack_start(w)
        w.signal_connect('clicked') do |w|
          puts "clicked #{w}, #{@frame_section_map[w]}"
          @current_section = @frame_section_map[w]
          refresh_argumentbox
        end
    end
  end

  def refresh_argumentbox
    @argedit_box # TODO
  end

end # class CommandWindow
