
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
    $l.debug self.to_s + " got new child: " + value.to_s
  end

end # class CliDef

