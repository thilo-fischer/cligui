
class CliDef; end

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
