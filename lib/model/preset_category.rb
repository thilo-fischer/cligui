class CliDef; end
class Category < CliDef; end

class PresetCategory < Category
  CHILD_CLASSES = [ Preset, PresetCategory ]
end # class PresetCategory
