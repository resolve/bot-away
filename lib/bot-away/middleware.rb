module BotAway
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      if request.POST
        # don't run botaway if the path for this request has been disabled
        disabled_path = BotAway.disabled_for.first['path']

        unless disabled_path.is_a?(Regexp) \
           and (disabled_path =~ request.env['PATH_INFO'])
          run_through_botaway(request)
        end
      end

      @app.call env
    end

    def run_through_botaway(request)
      request.POST.merge! BotAway::ParamParser.new(request.ip, request.POST).params
    end
  end
end
