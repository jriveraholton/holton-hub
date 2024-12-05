require 'sinatra'
require 'sinatra/activerecord'

set :database, {adapter: "sqlite3", database: "holtonhub.sqlite3"}

get '/' do
  "Holton Hub"
end