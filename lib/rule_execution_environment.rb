module HasShortName
  # HasShortName finds candidates by running full names through "rules",
  # which return nil or the shortened name.  RuleExecutionEnvironment acts
  # as both the context in which the rules are executed, and it keeps track
  # of successful matches (non-nil returns) so subsequent rules can act upon
  # it.
  class RuleExecutionEnvironment
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
  end
end
