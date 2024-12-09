require 'sinatra'
require 'sinatra/activerecord'
require 'oauth2'

require './models.rb'
require './s_config.rb'

set :database, {adapter: "sqlite3", database: "holtonhub.sqlite3"}
#use sessions to save content for user across application
enable :sessions
set :session_secret, SESSION_SECRET 

################################
###OAuth2 Google Login Functions
################################

before do
  pass if request.path_info == '/oauth2callback'
  pass if request.path_info == '/signout'

  if session[:access_token]
	access_token = OAuth2::AccessToken.from_hash(client, { 
			                                       :access_token => session[:access_token], 
			                                       :refresh_token =>  session[:refresh_token], 
			                                       :expires_at =>  session[:expires_at], 
			                                       :header_format => 'OAuth %s' } )
  end
end

def client
  client ||= OAuth2::Client.new(G_API_CLIENT, G_API_SECRET, {
		                          :site => 'https://accounts.google.com',
		                          :authorize_url => "/o/oauth2/auth",
		                          :token_url => "/o/oauth2/token"
	                            })
end

#determines if a user exists or should be directed to log in
def verify_user
  #some token exists, but is it a real user?
  if session[:access_token] != nil
	@active_user = User.find_by(secret: session[:access_token])
    #is no user recognized? Go to the sign_in page
	if(@active_user == nil)
	  redirect '/sign_in'
	end
  else
    #they've never signed in, so go to the sign in page
	redirect '/sign_in'
  end
end

#pull the google info based on the logged in user
def access_token
  return OAuth2::AccessToken.new(client, session[:access_token], :refresh_token => session[:refresh_token])
end

def g_redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/oauth2callback'
  uri.query = nil
  uri.to_s
end


#save newly logged in user into database
def save_user
  #get google info
  info = access_token.get("https://www.googleapis.com/oauth2/v3/userinfo").parsed
  @active_user = User.find_by(email: info["email"])

  if @active_user == nil #if the user doesn't exist already
    name = info["name"].split
	@active_user = User.create(
	  email: info["email"],
      firstname: name[0],
      lastname: name[name.length-1]
	)
    white_id = BwTeam.find_by(team_color: "white").id
    blue_id = BwTeam.find_by(team_color: "blue").id
    white_count = User.where(team_id: white_id).count
    blue_count = User.where(team_id: blue_id).count
    if white_count >= blue_id
      @active_user.team_id = white_id
    else
      @active_user.team_id = blue_id
    end
  end
  @active_user.secret = session[:access_token]
  @active_user.save
end

###########################

###########################
##### Routes ##############

#home route
get '/' do
  verify_user #make sure user is logged in, or force them to the login in page
  if @active_user != nil
    puts "LOGGED IN: " + @active_user.email
  end
  erb :index
end

get '/sign_in' do
  #if the session still knows about the user,
  #verify they still have the correct credentials and send them to their home page
  if session[:access_token] != nil
    puts "ACCESS TOKEN FOUND"
	@active_user = User.find_by(secret: session[:access_token])
	if(@active_user != nil)
      puts "ACTIVE USER STILL HERE"
	  redirect '/'
	end
  end

  puts "NO ACTIVE USER!"
  #the user needs to login with their unique google url
  @google_url = client.auth_code.authorize_url(:redirect_uri => g_redirect_uri,:scope => G_API_SCOPES,:access_type => "offline")
  erb :sign_in
end

#clear out sesson info when signing out
get '/signout' do
  session[:access_token] = nil
  session[:refresh_token] = nil
  redirect '/sign_in'
end

#load session with google info for user
get '/oauth2callback' do
  new_token = client.auth_code.get_token(params[:code], :redirect_uri => g_redirect_uri)
  session[:access_token]  = new_token.token
  session[:expires_at] = new_token.expires_at
  session[:refresh_token] = new_token.refresh_token
  save_user
  puts "Saved User!!!"
  puts @active_user.email.to_s
  redirect '/sign_in'
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
      team_id = BwTeam.find_by(team_color: data[3].downcase).id
      # assigns an admin role to administrators
      if data[4].downcase == "admin"
        is_admin = true
      else
        is_admin = false
      end
      #generates a default password in the format "gracedingholtonarms"
      password = (fname.downcase + lname.downcase + "holtonarms").to_s

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
  #generates a default password in the format "gdingholtonarms"
  password = (fname.downcase[0] + lname.downcase + holtonarms).to_s

  new_user = User.create(firstname: fname, lastname: lname, 
  email: email, secret: password, team_id: team_id, is_admin: is_admin)

  redirect '/'
end

get '/add_users' do
  erb :add_users
end

  ##########################################