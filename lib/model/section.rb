class ElementRenderer; end
class SectionRenderer < ElementRenderer; end

class Element; end

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
