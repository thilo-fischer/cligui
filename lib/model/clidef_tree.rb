
class CliDef; end
class Category < CliDef; end

class ClidefTree
  attr_reader :root
  def initialize(root_dir)
    @root = Category.new(root_dir)
    @root.gather_children
  end
end
