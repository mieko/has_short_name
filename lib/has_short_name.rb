require_relative "./has_short_name/version"


module HasShortName
  class << self
    attr_accessor :rules
  end

  private
  def name_split(s)
    r = s.split(/\s+/)
    return [r.first, nil, r.last] if r.size == 2

    return [r.first, r[1...(r.size - 1)].join(' '), r.last] if r.size > 3
    return r
  end
  module_function :name_split

  public
  self.rules = {
    just_first: -> (name) do
      first, *_ = HasShortName::name_split(name)
      first
    end,

    mc_abbreviation: -> (name) do
      first, mid, last = HasShortName::name_split(name)
      if last.gsub!(/\A(Mac|Mc|O\')(\S).*/i, '\1\2.')
        "#{first} #{mid} #{last}"
      else
        nil
      end
    end,

    hyphen_abbrev: -> (name) do
      first, mid, last = HasShortName::name_split(name)
      if last.match(/-/)
        parts = last.split(/\s*-\s*/)
        combined = parts.map{|v| v.chars.first}.join('-') + '.'
        "#{first} #{mid} #{combined}"
      else
        nil
      end
    end,

    first_and_last_initial: -> (name) do
      first, mid, last = HasShortName::name_split(name)
      "#{first} #{last.chars.first}."
    end,

    with_middle_names: -> (name) do
      first, mid, last = HasShortName::name_split(name)
      if mid
        mids = mid.split(/\s+/)
        midp = mids.map{|v| v.chars.first + '.'} .join(' ')
        "#{first} #{midp} #{last}"
      else
        nil
      end
    end,

    no_op: -> (name) do
      name
    end
  }

  module ClassMethods
    def has_short_name
      before_validation :assign_short_name
    end
  end

  module Methods
    def short_name_candidates
      after_rules = HasShortName.rules.map do |k, r|
        r.(name)
      end

      after_rules.compact!
      after_rules.map! {|v| v.gsub(/\s+/, ' ')}
      after_rules.uniq!
      after_rules
    end

    private
    def assign_short_name
      return if short_name.present? && !self.name_changed?

      scope = self.class.all
      short_name_candidates.each do |candidate|
        if (ex = scope.find_by(short_name: candidate)) && ex != self
          next
        else
          self.short_name = candidate
          break
        end
      end
    end
  end

  module ARHook
    def has_short_name(*args, **kwargs)
      include(HasShortName) unless is_a?(HasShortName)
      has_short_name(*args)
    end
  end

  def self.included(cls)
    cls.send(:include, Methods)
    cls.send(:extend,  ClassMethods)
  end
end

::ActiveRecord::Base.send(:extend, HasShortName::ARHook)
