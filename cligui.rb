#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

#require 'gtk2'
require 'rexml/document'


class CliDef

  #CHILD_CLASSES = [ Category, Program ]
  #BASEFILENAME = "clidef.xml"

  def initialize(directory)
    @directory = directory
    @children = {}
    self.class::CHILD_CLASSES.each { |c| @children[c] = [] }
    puts "new " + self.class.to_s + " object: " + inspect
  end

  # return new object if given path corresponds to this class, return nil otherwise
  def self.create_if_valid(path)
    filename = File.join(path, self::BASEFILENAME)
    if File.exist?(filename)
      obj = new(path) 
      obj.read_selffile(filename)
      obj
    end
  end

  def gather_children
    gather_children_from_directory(@directory, self.class::BASEFILENAME)
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
    puts "warning: ... " # TODO
  end

  def add_child(key, value)
    @children[key] << value
    puts self.to_s + " got new child: " + value.inspect
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
    puts "TODO: add section"
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
    obj = new(path) 
    obj.read_selffile(path)
    obj
  end

  def gather_children
    nil
  end

  def add_argument(e)
    puts "TODO: add argument"
  end

end # class Preset


class PresetCategory < Category
  CHILD_CLASSES = [ Preset, PresetCategory ]
end # class PresetCategory


clidef_root = Category.new("./cli-definitions")
clidef_root.gather_children
puts "====="
puts clidef_root.inspect

__END__

window = Gtk::Window.new

# # ???
# window.signal_connect("delete_event") {
#   puts "delete event occurred"
#   #true
#   false
# }

window.signal_connect("destroy") {
  Gtk.main_quit
}



window.show_all

Gtk.main
