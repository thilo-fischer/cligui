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

# call function on dir
# classify dir
# create object representing dir
# call function recursively on subdirs and add return values to list
# 

class CliDef

  @CHILD_CLASSES = [ Category, Program ]
  @BASENAME = "clidef.xml"

  def initialize(directory)
    @directory = directory
    @children = {}
    @CHILD_CLASSES,each { |c| @children[c] = {} }
  end

  # return new object if directory corresponds to this class, return nil otherwise
  def self.create_if_valid(dirname)
    filename = File.join(dirname, @BASENAME)
    if File.exist?(filename)
      obj = new(dirname) 
      obj.read_deffile(filename)
    end
  end

  def read_deffile(filename)
    self
  end

  def read_directory
    Dir.foreach(directory) do |entry|
      if entry == "." or entry == ".."
        next
      end
      path = File.join(directory, entry)
      if File.directory?(path)      
        read_subdirectory(path)
      elsif File.file?(path)
        read_file(path) if entry != @BASENAME
      else
        puts "warning: ..." # todo
      end
    end
  end

  def read_subdirectory(dirname)
    @CHILD_CLASSES,each do |cls|
      obj = cls.create_if_valid(dirname)
      if obj
        add_child(cls, obj)
        obj.read_directory
        return obj
      end
    end
  end

  def read_file(path)
    puts "warning: ignoring file " + path
  end

  def add_child(key, value)
    @children[key] << value
  end

end # class CliDif

#class CliDef
#
#  def read(dirname)
#    [Category, Program].each do |clazz|
#      filename = File.join(dirname, clazz.BASEFILENAME)
#      if File.exist?(filename)
#        add_child(clazz, clazz.new(filename))
#        break
#      end
#    end
#  end
#
#  def add_child()
#  end
#
##  def self.process_dir(dirname)
##    Dir.foreach(dirname) do |entry|
##      if entry == "." or entry == ".."
#        next
#      end
#      path = File.join(dirname, entry)
#      if File.directory?(path)      
#        process_dir( Category.read(path)
#      elsif File.file?(path)
#        category.add_child CliDef.read(path)
#      else
#        puts "warning: ..." # todo
#      end
#    end
#  end
#
#end # class CliDef

class Category < CliDef

  @BASEFILENAME = "category.xml"

  def initialize(name, description)
    @name = name
    @description = description
    @subcategories = []
    @programs = []
  end

  def self.process_dir(dirname, parent)
    this = read(dirname) 
    parent.add_subcategory(this)
    Dir.foreach(dirname) do |entry|
      if entry == "." or entry == ".."
        next
      end
      path = File.join(dirname, entry)
      if File.directory?(path)      
        process_dir(path, this)
      end
    end
  end

  def add_subcategory(sub)
    @subcategories << sub
  end

  def add_program(program)
    @programs << program
  end

end # class Category

class Program < CliDef

  BASEFILENAME = "cli.xml"

  def initialize()
    @presets = []
  end

  def self.read(dirname)
    doc = REXML::Document.new File.new(File.join(dirname, BASEFILENAME))
    name = doc.
    description = doc.
    new(name, description)
  end

  def add_preset(preset)
    @presets << preset
  end

end # class Program

class Preset < CliDef

  def self.read(filename)
  end

end # cliss Preset

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
