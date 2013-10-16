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
      if last && last.gsub!(/\A(Mac|Mc|O\')(\S).*/i, '\1\2.')
        "#{first} #{mid} #{last}"
      else
        nil
      end
    end,

    hyphen_abbrev: -> (name) do
      first, mid, last = HasShortName::name_split(name)
      if last && last.match(/-/)
        parts = last.split(/\s*-\s*/)
        combined = parts.map{|v| v.chars.first}.join('-') + '.'
        "#{first} #{mid} #{combined}"
      else
        nil
      end
    end,

    first_and_last_initial: -> (name, already_matched) do
      # This isn't an option if we've already got a McName, because it's
      # pretty much a special case.
      if (already_matched & [:mc_abbreviation, :hyphen_abbrev]) != []
        return nil
      end

      first, mid, last = HasShortName::name_split(name)
      return nil if last.nil?
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
    def has_short_name(only: nil)
      before_validation :assign_short_name
      @short_name_options ||= {}
      @short_name_options[:only] = only.nil? ? (->(m) { true }) : only
    end

    def adjust_short_names!(scope: nil)
      scope ||= self.all
      scope = scope.to_a

      # Our main structure here is:
      # { 'Mike' =>  [[user1, candidates1],
      #               [user2, candidates2]] }
      name_map = scope.map do |u|
        [u, u.short_name_candidates]
      end.group_by do |r|
        r.last.first
      end

      loop do
        adj_map = {}
        name_map.each do |k, v|
          if v.size == 1
            adj_map[k] = v
          else
            resolve_conflicts(k, v) do |new_key, urec|
              adj_map[new_key] ||= []
              adj_map[new_key].push(urec)
            end
          end
        end
        name_map = adj_map

        # We're done if each entry is singular, OR unsolvable.
        done = name_map.all? do |k, v|
          v.size == 1 || v.all? {|u, candidates| candidates.size == 1}
        end

        break if done
      end

      # Here, name_map should look something like:
      # name_map = {'Mike' => [[User(...), [leftover candidates]]]}
      name_map.each do |k, urecs|
        urecs.each do |urec|
          user = urec.first
          if @short_name_options[:only].(user)
            user.update(short_name: k) if user.short_name != k
          end
        end
      end
    end

    private
    def resolve_conflicts(k, urecs)
      urecs.each do |user, candidates|
        fail "empty candidate list" if candidates.empty?
        fail "conflicted key not first" if candidates.first != k
        if candidates.size == 1
          yield [candidates.first, [user, [candidates.first]]]
        else
          yield [candidates[1], [user, candidates[1..-1]]]
        end
      end
    end
  end

  module Methods
    def short_name_candidates
      # For models that fail the predicate, the name is the only
      # candidate.
      options = self.class.instance_variable_get(:@short_name_options)
      return [name] if !options[:only].(self)

      # The rules should be in priority order.  As we match,
      # we keep track of what's already matched and let further
      # rules opt out if they want.
      already_matched = []
      after_rules = HasShortName.rules.map do |k, r|
        candidate = (r.arity == 2 ? r.(name, already_matched) : r.(name))
        already_matched.push(k) if candidate
        candidate
      end

      after_rules.compact!
      after_rules.map! {|v| v.gsub(/\s+/, ' ')}
      after_rules.uniq!
      after_rules
    end

    private
    def assign_short_name
      if !((new_record? && short_name.blank?) ||
           (! new_record? && name_changed? && !short_name_changed?))
        return
      end

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
    def has_short_name(*args, **kw)
      include(HasShortName) unless is_a?(HasShortName)
      has_short_name(*args, **kw)
    end
  end

  def self.included(cls)
    cls.send(:include, Methods)
    cls.send(:extend,  ClassMethods)
  end
end

::ActiveRecord::Base.send(:extend, HasShortName::ARHook)
