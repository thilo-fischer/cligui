class ElementRenderer; end
#class FileArgRenderer < ElementRenderer; end
class FileArgRenderer < ArgumentRenderer; end

class FileArg < Argument

  RENDERER = FileArgRenderer

  def initialize(xml, start_active = false)
    super
    @type = xml.attributes['type']
    @type = 'fdlbcpsD' if not @type or @type == '*'
    # "true"|"false"|nil == 'true'. Catching typos and invalid strings (like 'Fasle') is the DTDs job.
    # TODO XML validation with DTD file
    @mustexist = xml.attributes['mustexist'] == 'true'
  end

end

