require 'sinatra'
require 'sinatra/activerecord'
require './models.rb'
set :database, {adapter: "sqlite3", database: "holtonhub.sqlite3"}

get '/' do
  erb :index
end


post '/create_users' do #creates users based on text file submitted by user
  if params[:accountsFile] && params[:accountsFile][:filename] #only reads file if it exists & has been submitted
    file = params[:accountsFile][:tempfile].read
    students = file.split("\n") #breaks document into a list of student data
    students.each do |student|
      data = student.split(",") # splits individual student data into array
      #format: first name, last name, email, team color, role
      fname = data[0]
      lname = data[1]
      email = data[2]
      team_id = BwTeam.find_by(team_color: params[:team].downcase).id
      # assigns an admin role to administrators
      if data[4].downcase == "admin"
        is_admin = true
      else
        is_admin = false
      end
      #generates a default password in the format "gracedingholtonarms"
      password = (fname.downcase + lname.downcase + "holtonarms").to_s

      #generates a username in the format "grace.ding.2025"
      username = email.split("@")[0]

      new_user = User.create(firstname: fname, lastname: lname, 
      email: email, secret: password, team_id: team_id, is_admin: is_admin)
    end
    redirect '/'
  end
end

post '/create_single_user' do #creates a single user based on user-submitted information
  fname = params[:fname]
  lname = params[:lname]
  email = params[:email]
  is_admin = param[:is_admin] #preferably this is a yes/no checkbox
  team_id = BwTeam.find_by(team_color: params[:team].downcase).id
  end
  #generates a default password in the format "gdingholtonarms"
  password = (fname.downcase[0] + lname.downcase + holtonarms).to_s

  #generates a username in the format "gding100"
  username = fname.downcase[0] + lname.downcase + rand(100..9999).to_s

  new_user = User.create(firstname: fname, lastname: lname, 
  email: email, secret: password, team_id: team_id, is_admin: is_admin)

  redirect '/'
end

get '/add_users' do
  erb :add_users
end