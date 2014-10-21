class ElementRenderer; end
class SectionRenderer < ElementRenderer; end
class SwitchRenderer < ElementRenderer; end
class FlagRenderer < ElementRenderer; end
class ArgumentRenderer < ElementRenderer; end
class FileArgRenderer < ElementRenderer; end

class Element
  
  RENDERER = ElementRenderer
  attr_reader :title
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

class Section < Element

  attr_reader :title, :count_min, :count_max

  RENDERER = SectionRenderer

  def initialize(xml, start_active = false)
    super
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

  def self.new_toplevel(xml)
    s = new(xml, true)
    s.active = true # FIXME shold be set accordingly by constructor
    raise unless s.active?
    s
  end

  def first_element
    @elements.first
  end

  def single_element?
    @elements.length == 1
  end

  def each_element
    @elements.each { |e| yield(e) }
  end

  def to_cmdline
    line = ""
    each_element do |e|
      text = e.to_cmdline
      line += text + " " unless text.empty?
    end
    line.rstrip
  end

end # class Section

class Switch < Element
  RENDERER = SwitchRenderer
  @@instances = {} # FIXME instances-hash must be section-specific
  def initialize(xml)
    super
    @longname = nil
    @shortname = nil
    @longname  = xml.elements['longname'].text if xml.elements['longname']
    if @longname
      raise "argement occurs multiple times: `#{@longname}'" if @@instances.key?(@longname)
      @@instances[@longname] = self
      @title ||= @longname
    end
    @shortname = xml.elements['shortname'].text if xml.elements['shortname']
    if @shortname
      raise "argement occurs multiple times: `#{@shortname}'" if @@instances.key?(@shortname)
      @@instances[@shortname] = self
      @title ||= @shortname
    end
  end

  def to_cmdline
    if @active
      @longname || @shortname
    else
      ""
    end
  end

end

class Flag < Switch
  RENDERER = FlagRenderer
  attr_reader :argument
  def initialize(xml)
    super
    if @longname
      @longname_sep  = xml.elements['longname' ].attributes['separator']
      @longname_sep  ||= "=" # FIXME define constant for default separator string
    end
    if @shortname
      @shortname_sep = xml.elements['shortname'].attributes['separator']
      @shortname_sep ||= " " # FIXME define constant for default separator string
    end
    @argument = Section.new(xml.elements['section'])
  end

  def to_cmdline
    if @active
      if @longname
        @longname + @longname_sep
      else
        @shortname + @shortname_sep
      end + @argument.to_cmdline
    else
      ""
    end
  end

end

class Argument < Element
  RENDERER = ArgumentRenderer
  def initialize(xml)
    super
    @raw_text = xml.attributes['default'] || ""
  end
  def escaped_text
    if @raw_text.empty?
      ""
    else
      # TODO really escape!
      '"' + @raw_text + '"'
    end
  end
  def to_cmdline
    escaped_text
  end
end

class FileArg < Argument
  RENDERER = FileArgRenderer
  def initialize(xml)
    super
    @type = xml.attributes['type']
    @type = 'fdlbcpsD' if not @type or @type == '*'
    # "true"|"false"|nil == 'true'. Catching typos and invalid strings (like 'Fasle') is the DTDs job.
    @mustexist = xml.attributes['mustexist'] == 'true'
  end
end

