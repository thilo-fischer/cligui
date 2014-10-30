
class CliDef; end
class Category < CliDef; end
class Preset < CliDef; end
class PresetCategory < Category; end

class Element; end
class Section < Element; end

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
    @sections << Section.new(e, true)
  end

  # must be passed a block that will be run once on every section.
  def each_section
    @sections.each { |s| yield(s) }
  end

  def cmdline
    line = "#{@executable} "
    each_section do |s|
      text = s.to_cmdline
      line += text + " " unless text.empty?
    end
    line.rstrip
  end

end # class Program
