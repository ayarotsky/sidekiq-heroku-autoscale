# frozen_string_literal: true

require 'sidekiq'

require 'sidekiq/heroku_autoscale/heroku_app'
require 'sidekiq/heroku_autoscale/middleware'
require 'sidekiq/heroku_autoscale/poll_interval'
require 'sidekiq/heroku_autoscale/process'
require 'sidekiq/heroku_autoscale/queue_system'
require 'sidekiq/heroku_autoscale/scale_strategy'

module Sidekiq
  module HerokuAutoscale
    class << self
      attr_reader :app
      attr_writer :exception_handler

      def init(options)
        options = options.transform_keys(&:to_sym)
        @app = HerokuApp.new(**options)

        unless @app.live?
          ::Sidekiq.logger
                   .warn('Heroku platform API is not configured for Sidekiq::HerokuAutoscale')
        end

        # configure sidekiq queue server
        ::Sidekiq.configure_server do |config|
          config.on(:startup) do
            dyno_name = ENV['DYNO']
            next unless dyno_name

            process = @app.process_by_name(dyno_name.split('.').first)
            next unless process

            process.ping!
          end

          config.server_middleware do |chain|
            chain.add(Middleware, @app)
          end

          # for jobs that queue other jobs...
          config.client_middleware do |chain|
            chain.add(Middleware, @app)
          end
        end

        # configure sidekiq app client
        ::Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add(Middleware, @app)
          end
        end

        # immedaitely wake all processes during client launch
        @app.ping! unless ::Sidekiq.server?

        @app
      end

      def exception_handler
        @exception_handler ||= lambda do |ex|
          p ex
          puts ex.backtrace
        end
      end
    end
  end
end
