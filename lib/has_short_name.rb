require 'name_finder'
require 'rule_set'
require 'default_rule_set'
require 'rule_execution_environment'

module HasShortName
  
  # This is written in a lame, meta-programming style so it'll work with
  # multiple configurations in a single model.  has_short_name has to generate
  # methods with different configurations, and a closure does that nicely.
  module ClassMethods
    def has_short_name(only: nil, from: nil, column: nil, rules: nil,
                       auto_adjust: false)
      only   ||= -> { true }
      column ||= :short_name
      from   ||= :name
      rules  ||= HasShortName::DefaultRuleSet.new

      # Allow passing in strings
      column, from = [column, from].map(&:to_sym)
      plural_column = column.to_s.pluralize

      # Handle `only: :predicate?` argument.
      # With correct binding via function invocation.
      if only.is_a?(Symbol)
        only = ->(symbol) { -> { send(symbol) } }.(only)
      end

      resolve_conflicts = ->(k, urecs, &cb) do
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
              resolve_conflicts.(k, v) do |new_key, urec|
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


      define_method("#{column}_candidates") do
        name = send(from)
        existing_short_name = send(column)

        # For models that fail the predicate, the name is the only
        # candidate.
        unless instance_exec(&only)
          return [existing_short_name] unless existing_short_name.blank?
          return [name]
        end

        # Rules are executed in a special, blank-ish execution environment
        # that has a few utility functions
        execution_environment = RuleExecutionEnvironment.new

        after_rules = []
        # The rules should be in priority order.
        rules.executing(execution_environment) do
          after_rules = rules.map do |key, rule|
            rule.call(name).tap do |result|
              execution_environment.already_matched.push(key) if result
            end
          end
        end

        after_rules.compact!
        after_rules.map! {|v| v.gsub(/\s+/, ' ')}
        after_rules.uniq!
        after_rules
      end


      # Updates regardless
      define_method("assign_#{column}!") do |scope: nil|
        scope ||= self.class.all
        send("#{column}_candidates").each do |candidate|
          if (ex = scope.find_by(column => candidate)) && ex != self
            next
          else
            send("#{column}=", candidate)
            break
          end
        end
      end


      # Updates if changed.
      define_method("assign_#{column}") do |scope: nil|
        changed_keys = changed_attributes.keys.map(&:to_sym)
        if ((new_record? && send(column).blank?) ||
            (! new_record? && changed_keys.include?(from) &&
              !changed_keys.include?(column)))
          send("assign_#{column}!", scope: scope)
        end
      end

      before_validation "assign_#{column}".to_sym

      if auto_adjust
        after_save do
          self.class.send("adjust_#{plural_column}!".to_sym)
        end
      end

    end
  end

  def self.included(klass)
    klass.instance_eval do
      extend ClassMethods
    end
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
