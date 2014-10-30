class ElementRenderer; end
class SwitchRenderer < ElementRenderer; end

class Element; end

class Switch < Element

  RENDERER = SwitchRenderer

  @@instances = {} # FIXME instances-hash must be section-specific
  
  def initialize(xml, start_active = false)
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
