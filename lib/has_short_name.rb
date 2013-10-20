module HasShortName

  # HasShortName finds candidates by running full names through "rules",
  # which return nil or the shortened name.  RuleExecutionEnvironment acts
  # as both the context in which the rules are executed, and it keeps track
  # of successful matches (non-nil returns) so subsequent rules can act upon
  # it.
  class RuleExecutionEnvironment < BasicObject
    attr_reader :already_matched

    def initialize
      @already_matched = []
    end

    def split_name(s)
      r = s.split(/\s+/)
      return [r.first, nil, r.last] if r.size == 2

      return [r.first, r[1...(r.size - 1)].join(' '), r.last] if r.size > 3
      return r
    end

    def execute_rule(key, name, rule)
      instance_exec(name, &rule).tap do |r|
        already_matched.push(key) if r
      end
    end
  end

  # For now, these rules are only appropriate for anglo-style names.  Order here
  # is important: they're run top-down
  DEFAULT_RULES = {
    just_first: -> (name) do
      first, *_ = split_name(name)
      first
    end,

    mc_abbreviation: -> (name) do
      first, mid, last = split_name(name)
      if last && last.gsub!(/\A(Mac|Mc|O\')(\S).*/i, '\1\2.')
        "#{first} #{mid} #{last}"
      else
        nil
      end
    end,

    hyphen_abbrev: -> (name) do
      first, mid, last = split_name(name)
      if last && last.match(/-/)
        parts = last.split(/\s*-\s*/)
        combined = parts.map{|v| v.chars.first}.join('-') + '.'
        "#{first} #{mid} #{combined}"
      else
        nil
      end
    end,

    first_and_last_initial: -> (name) do
      # This isn't an option if we've already got a McName, because it's
      # pretty much a special case.
      if (already_matched & [:mc_abbreviation, :hyphen_abbrev]) != []
        return nil
      end

      first, mid, last = split_name(name)
      return nil if last.nil?
      "#{first} #{last.chars.first}."
    end,

    with_middle_names: -> (name) do
      first, mid, last = split_name(name)
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
    def has_short_name(only: nil, from: nil, column: nil, rules: nil)
      only   ||= ->(m) { true }
      column ||= :short_name
      from   ||= :name
      rules  ||= HasShortName::DEFAULT_RULES

      # Allow passing in strings
      column, from = [column, from].map(&:to_sym)
      plural_column = column.to_s.pluralize

      # Handle `only: :predicate?` argument
      if only.is_a?(Symbol)
        puts "ONLY=#{only.inspect}"
        predicate_symbol = only
        only = ->(m) { m.send(predicate_symbol) }
      end

      define_singleton_method("adjust_#{plural_column}!") do |scope: nil|
        scope ||= self.all
        scope = scope.to_a

        # Our main structure here is:
        # { 'Mike' =>  [[user1, candidates1],
        #               [user2, candidates2]] }
        name_map = scope.map do |u|
          [u, u.send("#{column}_candidates")]
        end.group_by do |r|
          r.last.first
        end

        loop do
          adj_map = {}
          name_map.each do |k, v|
            if v.size == 1
              adj_map[k] = v
            else
              send("resolve_#{column}_conflicts", k, v) do |new_key, urec|
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
            user.update(column => k) if user.send(column) != k
          end
        end
      end


      define_singleton_method("resolve_#{column}_conflicts") do |k, urecs, &cb|
        urecs.each do |user, candidates|
          fail "empty candidate list" if candidates.empty?
          fail "conflicted key not first" if candidates.first != k
          if candidates.size == 1
            cb.([candidates.first, [user, [candidates.first]]])
          else
            cb.([candidates[1], [user, candidates[1..-1]]])
          end
        end
      end


      define_method("#{column}_candidates") do
        name = send(from)
        # For models that fail the predicate, the name is the only
        # candidate.
        return [name] if !only.(self)

        # Rules are executed in a special, blank-ish execution environment
        # that has a few utility functions
        execution_environment = RuleExecutionEnvironment.new

        # The rules should be in priority order.
        after_rules = rules.map do |key, rule|
          execution_environment.execute_rule(key, name, rule)
        end

        after_rules.compact!
        after_rules.map! {|v| v.gsub(/\s+/, ' ')}
        after_rules.uniq!
        after_rules
      end


      define_method("assign_#{column}") do
        changed_keys = changed_attributes.keys.map(&:to_sym)

        if !((new_record? && send(column).blank?) ||
             (! new_record? && changed_keys.include?(from) &&
              !changed_keys.include?(column)))
          return
        end

        scope = self.class.all
        send("#{column}_candidates").each do |candidate|
          if (ex = scope.find_by(column => candidate)) && ex != self
            next
          else
            send("#{column}=", candidate)
            break
          end
        end
      end

      before_validation "assign_#{column}".to_sym
    end
  end

  def self.included(cls)
    cls.send(:extend, ClassMethods)
  end
end

if defined?(ActiveRecord::Base)
  class << ActiveRecord::Base
    def has_short_name(*args, **kw)
      include HasShortName
      has_short_name(*args, **kw)
    end
  end
end
