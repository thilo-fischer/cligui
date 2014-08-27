#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'
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

class CliDef

  #CHILD_CLASSES = [ Category, Program ]
  #BASEFILENAME = "clidef.xml"

  attr_reader :title, :description

  def initialize(directory)
    @directory = directory
    @children = {}
    self.class::CHILD_CLASSES.each { |c| @children[c] = [] }
    $l.debug "new " + self.class.to_s + " object: " + inspect
  end

  # return new object if given path corresponds to this class, return nil otherwise
  def self.create_if_valid(path)
    filename = File.join(path, self::BASEFILENAME)
# FIXME redundancy with Preset.create_if_valid
    if File.file?(filename) or File.symlink?(filename)
      obj = new(path) 
      obj.read_selffile(filename)
      obj
    end
  end

  def gather_children
    gather_children_from_directory(@directory, self.class::BASEFILENAME)
  end

  def leaf_node?
    self.class::CHILD_CLASSES.empty?
  end

  # must be passed a block that will be run once on every child.
  # order of children is grouped by the classes the children belong to, classes ordered as given by CHILD_CLASSES
  # TODO "class group" internal ordering
  def each_child
    self.class::CHILD_CLASSES.each do |clazz|
      @children[clazz].each { |child| yield(child) }
    end
  end

  def has_children?
    self.class::CHILD_CLASSES.find { |c| ! @children[c].empty? } # FIXME
  end

  # return array of all children, grouped by the classes the children belong to, classes ordered as given by CHILD_CLASSES
  # TODO "class group" internal ordering
  def get_children
    self.class::CHILD_CLASSES.collect { |result, c| result << @children[c] } # FIXME
    result
  end

private

  def gather_children_from_directory(directory, *entries_to_skip)
    Dir.foreach(directory) do |entry|
      if entry == "." or entry == ".." or entries_to_skip.include?(entry)
        next
      end
      add_child_from_path(File.join(directory, entry))
    end
  end

  def add_child_from_path(path)
   self.class::CHILD_CLASSES.each do |cls|
      child = cls.create_if_valid(path)
      if child
        add_child(cls, child)
        child.gather_children
        return child
      end
    end
    $l.warn "warning: ... " # TODO
  end

  def add_child(key, value)
    @children[key] << value
    $l.debug self.to_s + " got new child: " + value.inspect
  end

end # class CliDif

class Category < CliDef; end
class Program  < CliDef; end
class Preset   < CliDef; end
class PresetCategory < Category; end

class Category < CliDef

  CHILD_CLASSES = [ Category, Program ]
  BASEFILENAME = "category.xml"

  def read_selffile(filename)
    # TODO verify document validity using DTD file and ignore invalid files
    doc = REXML::Document.new File.new(filename)
    root = doc.root
    @title       = root.elements["title"].text
    @description = root.elements["description"].text
  end

end # class Category


class Program < CliDef

  CHILD_CLASSES = [ Preset, PresetCategory ]
  BASEFILENAME = "cli.xml"

  def read_selffile(filename)
    # TODO verify document validity using DTD file and ignore invalid files
    doc = REXML::Document.new File.new(filename)
    root = doc.root
    @description = root.elements["description"].text
    @executable  = root.elements["executable"].text
    titleelement = root.elements["title"]
    if titleelement
      @title = titleelement.text
    else
      @title = @executable
    end
    doc.elements.each("command/section") { |e| add_section(e) }
  end

  def gather_children
    gather_children_from_directory(File.join(@directory, Preset::DIRNAME), self.class::BASEFILENAME)
  end

  def add_section(e)
    $l.unknown "TODO: add section"
  end

end # class Program


class Preset < CliDef

  CHILD_CLASSES = []
  DIRNAME = "presets"

  def read_selffile(filename)
    # TODO verify document validity using DTD file and ignore invalid files
    doc = REXML::Document.new File.new(filename)
    root = doc.root
    @title       = root.elements["title"].text
    @description = root.elements["description"].text
    doc.elements.each("preset/argument") { |e| add_argument(e) }
  end

  def self.create_if_valid(path)
    if File.file?(path) or File.symlink?(path)
      obj = new(path) 
      obj.read_selffile(path)
      obj
    end
  end

  def gather_children
    nil
  end

  def add_argument(e)
    $l.unknown "TODO: add argument"
  end

end # class Preset


class PresetCategory < Category
  CHILD_CLASSES = [ Preset, PresetCategory ]
end # class PresetCategory


clidef_root = Category.new("./cli-definitions")
clidef_root.gather_children


## gui

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

window = Gtk::Window.new("cligui - A Graphical Frontend to Command Line Interfaces") 
window.resizable = true
window.border_width = 10 
window.signal_connect('destroy') { Gtk.main_quit } 
window.set_size_request(800, 400)

treestore = Gtk::TreeStore.new(String, String)

def add_to_treestore(clidef, treestore, ts_iter = nil)
  ts_iter = treestore.append(ts_iter)
  ts_iter[TITLE_IDX] = clidef.title
  ts_iter[DESC_IDX]  = clidef.description
  clidef.each_child { |child| add_to_treestore(child, treestore, ts_iter) }
end

clidef_root.each_child { |child| add_to_treestore(child, treestore) }

widgets = {
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
                'clicked' => Proc.new { raise "not yet implemented" }
            }
        }
    },
}
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

pack_widgets(window, widgets)

window.show_all
Gtk.main
