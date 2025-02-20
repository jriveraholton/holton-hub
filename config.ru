require './app'

use Rack::Session::Cookie, :key => 'rack.session',
                            :expire_after => 2592000, # In seconds
                            :secret => SESSION_SECRET

#use Rack::Session::Pool, :domain => 'holtonhub.org', :expire_after => 60 * 60 * 24 * 365


run HoltonHubApp
