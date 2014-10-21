
require 'rexml/document'

class CliDef; end

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
