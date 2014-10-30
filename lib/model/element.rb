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

  def initialize(xml, start_active = false, default_count = [1, 1])
    @title     = xml.attributes['title']
    @title     ||= xml.elements['title'].text if xml.elements['title']
    $l.debug "initialize #{self.inspect}"
    @description = xml.elements['description'].text if xml.elements['description']
    @helptext    = xml.elements['helptext'].text if xml.elements['helptext']

    count_spec = xml.attributes['count'] || default_count
    set_count(count_spec)

    @renderer = nil
    xml_active = xml.attributes['default_active']
    if xml_active != nil
      @active = (xml_active == "true")
    else
      @active = start_active
    end
  end # Element.initialize
  
  def self.create(xml, start_active = false)
    case xml.name
    when "section"
      Section.new(xml, start_active)
    when "switch"
      Switch.new(xml, start_active)
    when "flag"
      Flag.new(xml, start_active)
    when "argument"
      Argument.new(xml, start_active)
    when "file"
      FileArg.new(xml, start_active)
    else
      raise "Invalid XML element: `#{xml.name}'"
    end
  end # Element.create

  private def set_count(count_spec)
    case count_spec
    when Array
      raise "invalid array: #{count_spec}" unless count_spec.length == 2
      @count_min = count_spec[0]
      @count_max = count_spec[1]
    when /^\*$/
      @count_min = 0
      @count_max = -1
    when /^\+$/
      @count_min = 1
      @count_max = -1
    when /^\d+$/
      @count_min = Integer(count_spec)
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
      raise "Invalid count specification in .xml file: `#{count_spec}'"
    end
  end

  def active?
    active
  end

  def renderer
    @renderer ||= self.class::RENDERER.new(self)
  end

end # class Element
