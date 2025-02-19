require 'sinatra'
require 'sinatra/activerecord'
require 'oauth2'
require 'rack'

require './models.rb'
require './s_config.rb'

set :database, {adapter: "sqlite3", database: "holtonhub.sqlite3"}

#use sessions to save content for user across application
enable :sessions
set :session_secret, SESSION_SECRET

class HoltonHubApp < Sinatra::Base

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
    #if the client doesn't exist, create a new one,
    #otherwise keep the existig client
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
      @active_team_color = BwTeam.find(@active_user.team_id).team_color.downcase
    #    session[:team_color] = @active_team_color
    else
      #they've never signed in, so go to the sign in page
	    redirect '/sign_in'
    end
  end
  def check_admin #use for pages w/ admin-only access
    if not @active_user.is_admin
      redirect '/error'
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
    #try to find matching user
    @active_user = User.find_by(email: info["email"])
    
    if @active_user == nil #if the user doesn't exist already, they cannot log in
      redirect '/'
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
      puts "TEAM COLOR: " + @active_team_color.to_s
    end
    erb :index
  end

  get '/sign_in' do
    #if the session still knows about the user,
    #verify they still have the correct credentials and send them to their home page
    if session[:access_token] != nil
   	  @active_user = User.find_by(secret: session[:access_token])
      if @active_user != nil and @active_user.active
        redirect '/'
      end
    end

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

    redirect '/sign_in'
  end

  not_found do
    erb :error
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
    is_admin = params[:is_admin] != nil ? true : false
    team_id = BwTeam.find_by(team_color: params[:team].downcase).id
    role = params[:role]
    grade = params[:grade]

    
    #generates a default password in the format "gdingholtonarms"
    password = (fname.downcase[0] + lname.downcase + "holtonarms").to_s

    new_user = User.create(firstname: fname, lastname: lname, 
                           email: email, secret: password, team_id: team_id, is_admin: is_admin)
    if role == "Student" 
      Student.create(user_id: new_user.id, grade: Integer(grade)) 
    else 
      Facultystaff.create(user_id: new_user.id, grade: Integer(grade))
    end
    redirect '/'
  end

  get '/student' do
    # NEED TO ONLY AUTHORIZE IF STUDENT!!!!
    erb :student
  end

  get '/messages' do
    verify_user
    erb :messages
  end

  post '/messagesent' do
  end 

  get '/new_event' do
    verify_user
    erb :new_event
  end

  get '/bw_events' do
    @events = BwEvent.all 
    # @events.order(:event_date).reverse
    # puts "sorted"
    @blue_points = 0
    @white_points = 0
    verify_user
    @events.each do |event| #adds up points
      @blue_points += event.blue_points
      @white_points += event.white_points
    end
    erb :bw_events
  end

  get '/edit_event' do
    verify_user
    check_admin
    @event = BwEvent.find_by(id: params[:id])
    erb :edit_event
  end
    
  post '/create_event' do
    name = params[:eventName]
    date = params[:date].to_datetime #calendar on the frontend
    blue_pts = params[:blue_pts]
    white_pts = params[:white_pts]
    division = Division.find_by(name: params[:division]).id
    new_event = BwEvent.create(name: name, event_date: date, blue_points: blue_pts, white_points: white_pts, division_id: division) 
    redirect '/bw_events'
  end

  post '/update_event' do
    event = BwEvent.find_by(id: params[:id])
    puts "Event ID" + params[:id].to_s
    name = params[:eventName]
    date = params[:date].to_datetime #calendar on the frontend
    blue_pts = params[:blue_pts]
    white_pts = params[:white_pts]
    division = Division.find_by(id: params[:division]).id 
    event.update(name: name, event_date: date, blue_points: blue_pts, white_points: white_pts, division_id: division) # this one - should be an edit 
    redirect '/bw_events'
  end

  post '/delete_event' do
    event = BwEvent.find_by(id: params[:id]) 
    event.delete
    redirect '/bw_events'
  end

  get '/manage/manage_users' do
    verify_user
    check_admin
    @all_users = User.all
    @all_by_groups = {9 => [], 10 => [], 11 => [], 12 => [], :facstaff => []}

    #figure out which users are students and put them together by grade level
    #and put all faculty and staff together
    @all_users.each do |user|
      stu = Student.find_by(user_id: user.id)
      fac = Facultystaff.find_by(user_id: user.id)
      if stu != nil
        @all_by_groups[stu.grade].push(user)
      elsif fac != nil
        @all_by_groups[:facstaff].push(user)
      end
    end
    erb :user_management
  end

  get '/manage/add_users' do
    verify_user
    erb :add_users
  end

  post '/activation' do
    #set the given user based on name to active or inactive
    fname = params[:fname]
    lname = params[:lname]
    active = params[:act]
    user = User.find_by(firstname: fname, lastname: lname)
    user.active = active
    user.save

    redirect '/manage/manage_users'
  end

  get '/manage/create_user' do
    verify_user
    check_admin
    erb :create_single_user
  end

  get '/manage/manage_groups' do
    verify_user
    check_admin
    @all_sports = Group.where(group_type: "sport", active: true).order(level_id: :asc, name: :asc) 
    @all_clubs = Group.where(group_type: "club", active: true).order(level_id: :asc, name: :asc)
    @archived_groups = Group.where(active: false).order(group_type: :asc, level_id: :asc, name: :asc)
    erb :group_management
  end

  get "/manage/edit_group" do
    verify_user
    check_admin
    @group = Group.find(params[:id])
    erb :edit_group
  end 

  post "/manage/update_group" do
    group = Group.find(params[:id])
    group.update(name: params[:groupName], level_id: params[:level].to_i)
    if group.group_type == "sport"
      season = GroupSeason.find_by(group_id: group.id)
      season.update(season_id: params[:season].to_i)
    end
    redirect '/manage/manage_groups'
  end

  post "/manage/delete_group" do
    group = Group.find(params[:id])
    group.update(active: false)
    redirect '/manage/manage_groups'
  end 

  post "/manage/restore_group" do
    group = Group.find(params[:id])
    group.update(active: true)
    puts group.name
    redirect '/manage/manage_groups'
  end 

  post "/manage/trash_group" do
    group = Group.find(params[:id])
    if not group.active
      group.delete
      redirect '/manage/manage_groups'
    else
      erb :error
    end
    
  end

  get '/manage/add_group_members' do
    verify_user
    check_admin
    @all_sports = Group.where(group_type: "sport", active: true).order(level_id: :asc, name: :asc) 
    @all_clubs = Group.where(group_type: "club", active: true).order(level_id: :asc, name: :asc)
    
    erb :add_batch_group_members
  end

  post '/add_group_members' do
    group_id = params[:group].to_i
    file = params[:members_list][:tempfile].read
    students = file.split("\n")
  
    students.each do |email|
      use = User.find_by(email: email.delete("\r"))
      stu = Student.find_by(user_id: use.id)
      if GroupMember.find_by(student_id: stu.id, group_id: group_id) == nil
        GroupMember.create(student_id: stu.id, group_id: group_id)
      end
    end
    redirect '/all_clubs' #eventually redirect to the group you are adding members to
  end

  get '/faculty_page' do
  # THIS IS NOT COMPLETE --- NEEDS TO CHECK IF USER IS FACULTY ??
    erb :faculty_page
  end

  get '/club_droppout' do
    erb :club_droppout
  end

  post '/push_club_meeting' do
    #still need to build frontend 
    location = params[:location]
    date = params[:date]
    id = params[:id] #need to specifically pass as ID
    meeting = GroupMeetings.create(location: location, event_date: date, group_id: id)
  end

  get '/today' do
    verify_user
    erb :day_schedule
  end
  
  get '/all_clubs' do
    verify_user
    @high_commitment = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "high commitment").id).order(name: :asc)
    @interest = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "interest").id).order(name: :asc)
    @affinity_groups = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "affinity group").id).order(name: :asc)
    erb :all_clubs
  end

  get '/all_sports' do
    verify_user
    @all_sports = Group.where(group_type: "sport", active: true).order(level_id: :asc, name: :asc)
    #iterates thru and sorts all sports based on season
    @fall_sports = []
    @winter_sports = []
    @spring_sports = []
    #there should be a way to do this w/o hardcoding every season
    @all_sports.each do |sport|
      if GroupSeason.find_by(group_id: sport.id).season_id == Season.find_by(name: "Fall").id
        @fall_sports << sport
      elsif GroupSeason.find_by(group_id: sport.id).season_id == Season.find_by(name: "Winter").id
        @winter_sports << sport
      elsif GroupSeason.find_by(group_id: sport.id).season_id == Season.find_by(name: "Spring").id
        @spring_sports << sport
      end  
    end
    # @fall_sports1 = Group.where(GroupSeason.find_by(group_id: ))
    # @fall_sports = GroupSeason.where(season_id: Season.find_by(name: "Fall"))
    # @fall_sports = Group.where(GroupSeason.find_by(:group_id))
    # fall_sports_ids.each do |id|
    #   @fall_sports << Group.find(id)
    erb :all_sports
  end
  ##########################################
end
