#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'
require 'rexml/document'

class CliDefTree

  def initialize(dirname)
    @tree = parse_clidefs(dirname, Category.new("top", "root element of the tree (invisible to the user)"))
  end

def parse_clidefs(dirname, category)
  Dir.foreach(dirname) { |filename|
    if filename == "." or filename == ".."
      next
    elsif File.directory?(filename)      
      category.add_subcategory Category.read(File.join(dirname, filename))
    elsif File.file?(filename)
      category.add_child CliDef.read(File.join(dirname, filename))
    else
      puts "warning: ..." # todo
    end
  }
end # parse_clidefs

def parse_clidef(filename)
  listener = MyListener.new 
  file = File.new filename
  REXML::Document.parse_stream(file, listener)
end # parse_clidef

end # class CliDefs

class Category

  def initialize(name, description)
    @name = name
    @description = description
    @subcategories = []
    @children = []
  end

  def self.read(filename)
    doc = REXML::Document.new File.new(File.join(filename, "category.xml"))
    name = doc.
    description = doc.
    new(name, description)
  end

  def add_subcategories(sub)
    @subcategories << sub
  end

  def add_child(child)
    @children << child
  end

end # class Category

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
