#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'
require_relative 'window.rb'

class CliDef; end

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

