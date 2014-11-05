module HasShortName
  # For now, these rules are only appropriate for anglo-style names.  Order here
  # is important: they're run top-down
  class DefaultRuleSet < RuleSet
    rule def just_first(name)
      first, * = split_name(name)
      first
    end

    rule def mc_abbreviation(name)
      first, mid, last = split_name(name)
      if last && last.gsub!(/\A(Mac|Mc|O\')(\S).*/i, '\1\2.')
        "#{first} #{mid} #{last}"
      else
        nil
      end
    end

    rule def hyphen_abbrev(name)
      first, mid, last = split_name(name)
      if last && last.match(/-/)
        parts = last.split(/\s*-\s*/)
        combined = parts.map{|v| v.chars.first}.join('-') + '.'
        "#{first} #{mid} #{combined}"
      else
        nil
      end
    end

    rule def first_and_last_initial(name)
      # This isn't an option if we've already got a McName, because it's
      # pretty much a special case.
      if (already_matched & [:mc_abbreviation, :hyphen_abbrev]) != []
        return nil
      end

      first, mid, last = split_name(name)
      return nil if last.nil?
      "#{first} #{last.chars.first}."
    end

    rule def with_middle_names(name)
      first, mid, last = split_name(name)
      if mid
        mids = mid.split(/\s+/)
        midp = mids.map{|v| v.chars.first + '.'} .join(' ')
        "#{first} #{midp} #{last}"
      else
        nil
      end
    end

    rule def no_op(name)
      name
    end
  end
end
