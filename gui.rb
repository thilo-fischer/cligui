#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'

def pack_widgets(container, wgts)
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

class SelectionWindow

TITLE_IDX = 0
DESC_IDX  = 1

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
  clidef.each_child { |child| add_to_treestore(child, treestore, ts_iter) }
end

def initialize(clidef_root)

@window = Gtk::Window.new("cligui - A Graphical Frontend to Command Line Interfaces") 
@window.resizable = true
@window.border_width = 10 
@window.signal_connect('destroy') { Gtk.main_quit } 
@window.set_size_request(800, 400)

treestore = Gtk::TreeStore.new(String, String)

clidef_root.each_child { |child| add_to_treestore(child, treestore) }

selection_wgts = {
    :self => Gtk::VBox.new,
    :scrolled_win => {
        :self => Gtk::ScrolledWindow.new,
        :setup => Proc.new do |scrolled_win|
            scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
        end,
        :treeview => {
            :self => Gtk::TreeView.new,
            :setup => Proc.new do |treeview|
                setup_tree_view(treeview)
                treeview.model = treestore
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
                'clicked' => Proc.new { Gtk.main_quit }
            }
        },
        :next => {
            :self => Gtk::Button.new('Next'),
            :packing => Proc.new { |c, w| c.pack_end(w, FALSE, FALSE) },
            :signals => {
                'clicked' => Proc.new { @window.close }
            }
        }
    },
}

pack_widgets(@window, selection_wgts)
end # initialize

def show
@window.show_all
Gtk.main
end # show
end # class SelectionWindow
