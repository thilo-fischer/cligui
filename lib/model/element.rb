class ElementRenderer; end

class Element; end
class Section < Element; end
class Switch < Element; end
class Flag < Switch; end
class Argument < Element; end
class FileArg <  Argument; end

class Element
  
  RENDERER = ElementRenderer
  attr_reader :title, :description, :helptext
  attr_accessor :active

  def initialize(xml, start_active = false)
    @title     = xml.attributes['title']
    @title     ||= xml.elements['title'].text if xml.elements['title']
    $l.debug "initialize #{self.inspect}"
    @description = xml.elements['description'].text if xml.elements['description']
    @helptext    = xml.elements['helptext'].text if xml.elements['helptext']
    @renderer = nil
    @active = (xml.attributes['default_active'] == "true")
    @active = start_active if @active == nil
  end # Element.initialize
  
  def self.create(xml)
    case xml.name
    when "section"
      Section.new(xml)
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

  def active?
    active
  end

  def renderer
    @renderer ||= self.class::RENDERER.new(self)
  end

end # class Element
