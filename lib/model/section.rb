class ElementRenderer; end
class SectionRenderer < ElementRenderer; end

class Element; end

class Section < Element

  attr_reader :title, :count_min, :count_max

  RENDERER = SectionRenderer

  def initialize(xml, start_active = false)
    super(xml, start_active, [0, -1])

    @elements = []

    count_active = 0
    xml.elements.each do |xe|
      new_element = Element.create(xe)
      count_active += 1 if new_element.active?
      @elements << new_element
    end

    check_active_elements(count_active)
  end

  def check_active_elements(count_active)
    if single_element?
      first_element.active = true
    elsif count_active < @count_min
      if @count_min == 1
        first_element.active = true
        $l.warn "No element configured as default_active in section #{this}. Selected the first element (#{first_element}) as active element."
      else
        $l.warn "Too few elements in section #{this} configured default_active (#{count_active} configured, #{@count_min} active elements required)."
      end
    elsif count_active > @count_max and @count_max > 0
      if @count_max == 1
        first_active = nil
        @elements.for_each do |e|
          if e.active?
            if first_active
              e.active = false
            else
              first_active = e
            end
          end
        end
        $l.warn "#{count_active} elements configured as default_active in section #{this}. Deactivated all but the first active element (#{first_active})."
      else
        $l.warn "Too many elements in section #{this} configured default_active (#{count_active} configured, #{@count_max} active elements allowed)."
      end
    end
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
