
require 'rexml/document'

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
    self.class::CHILD_CLASSES.inject([]) { |result, c| result += @children[c] } # FIXME
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

end # class CliDef

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

  attr_reader :executable

  def initialize(directory)
    super
    @sections = []
  end

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
    @sections << Section.new(e)
  end

  # must be passed a block that will be run once on every section.
  def each_section
    @sections.each { |s| yield(s) }
  end

  def run_command
    raise "todo"
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

  def run_command
    raise "todo"
  end

end # class Preset


class PresetCategory < Category
  CHILD_CLASSES = [ Preset, PresetCategory ]
end # class PresetCategory

class ClidefTree
attr_reader :root
def initialize(root_dir)
@root = Category.new(root_dir)
@root.gather_children
end
end

class Section

  attr_reader :title, :count_min, :count_max

  def initialize(xml)
    @title = xml.attributes['title']

    # FIXME extract to method
    count = xml.attributes['count']
    case count
    when /^\*$/
      @count_min = 0
      @count_max = -1
    when /^\+$/
      @count_min = 1
      @count_max = -1
    when /^\d+$/
      @count_min = Integer(count)
      @count_max = @count_min
    when /^(\d+)\.\.(\d+|\*|n)$/
      @count_min = Integer(Regexp.last_match(1))
      max = Regexp.last_match(2)
      @count_max = case max
      when "*", "n"
        -1
      else
        Integer(max)
      end
    else
      raise "Invalid count specification in .xml file: `#{count}'"
    end

    @elements = []

    xml.elements.each do |xe|
      @elements << Element.create(xe)
    end
  end

  def each_element
    @elements.each { |e| yield(e) }
  end

end # class Section

class Element
  def initialize(xml)
    @description = xml.elements['description']
    @helptext    = xml.elements['helptext']
  end # Element.initialize
  def self.create(xml)
    case xml.name
    when "switch"
      Switch.new(xml)
    when "flag"
      Flag.new(xml)
    when "argument"
      Argument.new(xml)
    when "file"
      FileArg.new(xml)
    else
      raise "Invalid XML element: `#{xml.name}'"
    end
  end # Element.create
end # class Element

class Switch < Element
  @@instances = {} # FIXME instances-hash must be section-specific
  def initialize(xml)
    super
    @longname  = xml.elements['longname']
    if @longname
      raise "argement occurs multiple times: `#{@longname}'" if @@instances.key?(@longname)
      @@instances[@longname] = self
    end
    @shortname = xml.elements['shortname']
    if @shortname
      raise "argement occurs multiple times: `#{@shortname}'" if @@instances.key?(@shortname)
      @@instances[@shortname] = self
    end
  end
end

class Flag < Switch
  def initialize(xml)
    super
    # "mandatory"|"optional"|nil == 'optional'. Catching typos and invalid strings (like 'Manatory') is the DTDs job.
    @arg_optional  = xml.elements['argument'] == 'optional'
    @longname_sep  = xml.elements['longname' ].attributes['separator']  if @longname
    @shortname_sep = xml.elements['shortname'].attributes['separator'] if @shortname
  end
end

class Argument < Element
  def initialize(xml)
    super
    # ... (TODO)
  end
end

class FileArg < Argument
  def initialize(xml)
    super
    @type = xml.attributes['type']
    @type = 'fdlbcpsD' if not @type or @type == '*'
    # "true"|"false"|nil == 'true'. Catching typos and invalid strings (like 'Fasle') is the DTDs job.
    @mustexist = xml.attributes['mustexist'] == 'true'
  end
end

