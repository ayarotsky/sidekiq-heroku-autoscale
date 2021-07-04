# frozen_string_literal: true

require 'sidekiq/heroku_autoscale/process'
require 'sidekiq/heroku_autoscale/web_extension'

if defined?(::Sidekiq::Web)
  ::Sidekiq::Web.register(::Sidekiq::HerokuAutoscale::WebExtension)
  ::Sidekiq::Web.tabs['Dynos'] = 'dynos'
end
