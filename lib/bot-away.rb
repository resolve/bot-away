require 'action_controller'
require 'action_view'

require 'bot-away/param_parser'
require 'bot-away/middleware'
require 'bot-away/action_view/helpers/instance_tag'
require 'bot-away/spinner'
require 'bot-away/version'
require 'bot-away/railtie'

module BotAway
  autoload :TestCase, 'bot-away/test_case'

  class << self
    attr_accessor :show_honeypots, :dump_params
    attr_writer :obfuscate_honeypot_warning_messages

    def obfuscate_honeypot_warning_messages?
      !!@obfuscate_honeypot_warning_messages
    end

    def unfiltered_params(*keys)
      unfiltered_params = instance_variable_get("@unfiltered_params") || instance_variable_set("@unfiltered_params", [])
      unfiltered_params.concat keys.flatten.collect { |k| k.to_s }
      unfiltered_params
    end

    alias_method :accepts_unfiltered_params, :unfiltered_params

    # options include:
    #   :controller
    #   :action
    #   :object_name
    #   :method_name
    #
    # excluded? will also check the current Rails run mode against disabled_for[:mode]
    def excluded?(options)
      options = options.stringify_keys
      nonparams = options.stringify_keys
      nonparams.delete 'object_name'
      nonparams.delete 'method_name'
      (options['object_name'] && options['method_name'] &&
              unfiltered_params_include?(options['object_name'], options['method_name'])) || disabled_for?(nonparams)
    end

    def unfiltered_params_include?(object_name, method_name)
      unfiltered_params.collect! { |u| u.to_s }
      if (object_name &&
              (unfiltered_params.include?(object_name.to_s) ||
                      unfiltered_params.include?("#{object_name}[#{method_name}]")) ||
          unfiltered_params.include?(method_name.to_s))
        true
      else
        false
      end
    end

    # Returns true if the given options match the options set via #disabled_for, or if the Rails run mode
    # matches any run modes set via #disabled_for.
    def disabled_for?(options)
      return false if @disabled_for.nil? || options.empty?
      options = options.stringify_keys

      @disabled_for.each do |set|
        if set['path'].is_a?(Regexp)
          return options['path'] =~ set['path']
        end

        if set.key?('mode')
          next unless ENV['RAILS_ENV'] == set['mode'].to_s
          return true if set.keys.length == 1
          # if there are more keys, then it looks something like:
          #   disabled_for :mode => 'development', :controller => 'tests'
          # and that means we need to check the next few conditions.
        end

        if set.key?('controller') && set.key?('action')
          return true if set['controller'] == options['controller'] && set['action'] == options['action']
        elsif set.key?('controller') && !set.key?('action')
          return true if set['controller'] == options['controller']
        elsif set.key?('action')
          return true if set['action'] == options['action']
        end
      end
      false
    end

    def disabled_for(options = {})
      @disabled_for ||= []
      if !options.empty?
        @disabled_for << options.stringify_keys
      end
      @disabled_for
    end

    def reset!
      self.show_honeypots = false
      self.dump_params = false
      self.obfuscate_honeypot_warning_messages = true
      self.unfiltered_params.clear
      self.disabled_for.clear
    end
  end

  delegate :accepts_unfiltered_params, :unfiltered_params, :to => :"self.class"

  reset! # set defaults
end
