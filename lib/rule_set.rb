require 'name_finder'

module HasShortName
  class RuleSet
    def self.rules
      @rules ||= NameFinder.create
    end

    def self.rule(method_name)
      rules[method_name] = method_name
    end

    include Enumerable
    def each(&block)
      rules.each(&block)
    end

    def rules
      @rules ||= NameFinder.create
    end

    def rule(rule_name, &block)
      rules[rule_name] = block
    end

    # Patching in the execution environment
    def respond_to?(method_name)
      super || (@exe_env && @exe_env.respond_to?(method_name))
    end

    def method_missing(method_name, *args)
      if @exe_env && @exe_env.respond_to?(method_name)
        return @exe_env.send(method_name, *args)
      end

      super
    end

    def executing(target, &block)
      old_exe_env = @exe_env
      @exe_env = target
      yield
    ensure
      @exe_env = old_exe_env
    end

    def initialize
      self.class.rules.each do |rule_name, method_name|
        rule(rule_name, &method(method_name))
      end
    end
  end

end
