require 'sinatra'
require 'sinatra/activerecord'

set :database, {adapter: "sqlite3", database: "holtonhub.sqlite3"}

get '/' do
  "Holton Hub"
end

get '/faculty_page' do
  erb :faculty_page
end

get '/club_droppout' do
  erb :club_droppout
end
