class ElementRenderer; end
class FlagRenderer < ElementRenderer; end

class Element; end
class Switch < Element; end

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
