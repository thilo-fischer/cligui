class ElementRenderer; end
class ArgumentRenderer < ElementRenderer; end

class Argument < Element

  RENDERER = ArgumentRenderer

  attr_accessor :raw_args

  def initialize(xml, start_active = false)
    super
    @raw_args = []
    if xml.attributes['default']
      @raw_args << xml.attributes['default']
    end
    xml.elements.each do |e|
      raise "invalid child element of argument" unless e.name == "default" # todo This could also be checked validating the XML with a DTD.
      @raw_args << e.text
    end
    $l.warn "too many default arguments for #{self}" if @raw_args.length > @count_max
  end
  
#def add(arg)
#@raw_args << arg
#end
#
#def remove(arg)
#@raw_args.remove(arg)
#end
#
#def clear
#@raw_args = []
#end
#
#def each_arg
#@raw_args.each { |a| yield a }
#end

  def escaped_text
    if @raw_args.empty?
      ""
    else
      # TODO really escape!
      '"' + @raw_args.join('" "') + '"'
    end
  end
  
  def to_cmdline
    escaped_text
  end

end

