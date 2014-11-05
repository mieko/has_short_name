module HasShortName
  # A mixin we include into our rule array to let us search by name,
  # like a hash.  Ordering is important in the rule set, so we can't
  # just go to a hash
  module NameFinder
    def [](key)
      if key.is_a?(Symbol)
        idx = find {|v| v[0] == key }
        super(idx)[1]
      else
        super
      end
    end

    def []=(key, value)
      if key.is_a?(Symbol)
        if idx = find {|v| v[0] == key }
          super(idx, value)
        else
          push([key, value])
        end
      else
        super
      end
    end

    module_function
    def create
      r = []
      class << r
        include NameFinder
      end
      r
    end
  end
end
