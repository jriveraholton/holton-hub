require 'sinatra'
require 'sinatra/activerecord'
require 'oauth2'
require 'rack'
require 'active_support'

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
    #session[:team_color] = @active_team_color
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

  def find_meetings
    if Student.where(user_id: @active_user.id) != nil 
      stu = Student.find_by(user_id: @active_user.id)
      my_groups = Group.where(group_type: "club", id: GroupMember.where(student_id: stu.id) + GroupLeader.where(student_id: stu.id))
      my_sports = Group.where(group_type: "sport", id: GroupMember.where(student_id: stu.id) + GroupLeader.where(student_id: stu.id))
      
    elsif Facultystaff.where(user_id: @active_user.id) != nil
      fac = Facultystaff.find_by(user_id: @active_user.id)
      my_groups = Group.where(group_type: "club", id: GroupAdvisor.where(facultystaff_id: fac.id))
      my_groups = Group.where(group_type: "sport", id: GroupAdvisor.where(facultystaff_id: fac.id))
      # my_groups = Group.where(id: GroupAdvisor.where(student_id: Student.find_by(user_id: @active_user.id).id).select(:group_id)).select(:id)
      # my_groups = Group.where(group_type: "sport", id: GroupAdvisor.where(student_id: Student.find_by(user_id: @active_user.id).id).select(:group_id)).select(:id)
    end
    @global_meetings = GroupMeeting.where(event_date: (Time.now.midnight)..(Time.now.midnight + 1.day))
    @global_games = Game.where(date: (Time.now.midnight)..(Time.now.midnight + 1.day), status: true)
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
    find_meetings
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

  get '/student' do
    # NEED TO ONLY AUTHORIZE IF STUDENT!!!!
    erb :student
  end

  ## MESSAGES and ANNOUNCEMENTS ##
  get '/send_message' do
    verify_user
    @groups = [] #list of message tag objects
    if @active_user.is_admin
      @groups = MessageTag.where(active: true)
    elsif Student.where(user_id: @active_user.id) != nil #if user is a student
      stu = Student.find_by(user_id: @active_user.id)
      if GroupLeader.where(student_id: stu.id) != nil #if user is a group leader        
        GroupLeader.where(student_id: stu.id).each do |grp| #iterates thru groupleader objects
          @groups << MessageTag.find_by(id: GroupMessagetag.find_by(group_id: grp.group_id).messagetag_id, active: true)
        end
      end
    elsif Facultystaff.where(user_id: @active_user.id) != nil
      fac = Facultystaff.find_by(user_id: @active_user.id)
      if GroupAdvisor.where(facultystaff_id: fac.id) != nil #if user is a club advisor
        GroupAdvisor.find_by(facultystaff_id: fac.id).each do |grp| #iterates thru groupleader objects
          @groups << MessageTag.find_by(id: GroupMessagetag.find_by(group_id: grp.group_id).messagetag_id, active: true)
        end
      end
    end
    erb :send_messages
  end

  post '/post_message' do
    # if params[:tags] != nil
    subj = params[:subject]
    cont = params[:content]
    author = params[:author].to_i
    
    time = Time.now
    puts "TIMEINZONE: " + time.in_time_zone("Eastern Time (US & Canada)").to_s
    time = time.in_time_zone("Eastern Time (US & Canada)")
    
    time = DateTime.new(time.year, time.month, time.day, time.strftime("%H").to_i + (time.strftime("%z").to_i/100), time.min, time.sec, time.zone)
    msg = Message.create(subject: subj, content: cont, sent_at: time, author_id: author)
    params[:tag].each do |tag|
      #associate it with each tag
      mt = MessageTag.find_by(recipient_tag: tag)
      MessageMessageTag.create(message_id: msg.id, message_tag_id: mt.id)
      #associate it with each person
      
      if tag == "Upper School"
        User.all.each do |use|
          if not UserMessage.where(user_id: use.id, message_id: msg.id).exists?
            UserMessage.create(user_id: use.id, message_id: msg.id)
          end
        end
      elsif tag.include? "Class of"
        Student.where(class_of: tag[-4..-1].to_i).each do |stu|
          puts tag[-4..-1]
          if not UserMessage.where(user_id: stu.user_id, message_id: msg.id).exists?
            UserMessage.create(user_id: stu.user_id, message_id: msg.id)
          end
        end
        #still need to do faculty staff
      else
        grp = Group.find_by(id: GroupMessagetag.find_by(messagetag_id: mt.id).group_id)
        
        memb = Student.where(id: GroupMember.where(group_id: grp.id).select(:student_id)) + Student.where(id: GroupLeader.where(group_id: grp.id).select(:student_id))
        memb.each do |stu|
          if not UserMessage.where(user_id: stu.user_id, message_id: msg.id).exists?
            UserMessage.create(user_id: stu.user_id, message_id: msg.id)
          end
        end
        
        fac = Facultystaff.where(id: GroupAdvisor.where(group_id: grp.id).select(:facultystaff_id))
        fac.each do |fs|
          if not UserMessage.where(user_id: fs.user_id, message_id: msg.id).exists?
            UserMessage.create(user_id: fs.user_id, message_id: msg.id)
          end
        end
      end
    end
    
    redirect '/announcements'
    # else
    #   redirect '/error' #need to code in a way to not submit tagless messages
    # end
  end 

  get '/announcements' do
    verify_user
    #this would be a lot easier if we used associations: ask mr. rivera
    # all grade-level grouping has to be hard-coded: ask if this is necessary
    # @all_msg = Message.where(recipient_tag: "Upper School").order({message: {sent_at: :desc}})


    # if Student.find_by(user_id: @active_user.id) != nil #if user is a student
    #   stu = Student.find_by(user_id: @active_user.id)
    #   mt = MessageTag.find_by(recipient_tag: "Class of " + stu.class_of.to_s)
    # elsif Facultystaff.find_by(user_id: @active_user.id) != nil
    #   fac = Facultystaff.find_by(user_id: @active_user.id)
    #   grades = Student.select(:class_of).distinct.sort.to_a
    #   if fac.grade == 12
    #     gr = grades[0].class_of
    #   elsif fac.grade == 11
    #     gr = grades[1].class_of
    #   elsif fac.grade == 10
    #     gr = grades[2].class_of
    #   else
    #     gr = grades[3].class_of
    #   end
    #   mt = MessageTag.find_by(recipient_tag: "Class of "+ gr.to_s)
    # end
    # @all_msg = Message.where(id: MessageMessageTag.where(message_tag_id: [mt.id, MessageTag.find_by(recipient_tag: "Upper School").id]).select(:message_id)).order(sent_at: :desc)
    cls_tags = []
    MessageTag.select(:recipient_tag).each do |tag|
      if tag.recipient_tag.include? "Class of"
        cls_tags << tag.recipient_tag
      end
    end
    @priority = Message.where(id: UserMessage.where(user_id: @active_user.id).select(:message_id).order(:unread)).where(id: MessageMessageTag.where(message_tag_id: MessageTag.where(recipient_tag: "Upper School").or(MessageTag.where(recipient_tag: cls_tags)).select(:id)).select(:message_id))
    @all_msg = Message.where(id: UserMessage.where(user_id: @active_user.id).select(:message_id).order(:unread)).where.not(id: @priority.select(:id))

    # MessageTag.find_by(recipient_tag: "Upper School").order(sent_at: :desc)
    # @my_msg = []
    
    
    #   GroupMember.where(student_id: Student.find_by(user_id: @active_user.id).id).each do |grpmemb|
    #     @my_msg << GroupMessagetag.find_by(group_id: grpmemb.group_id).messagetag_id
    #   end
    #   GroupLeader.where(student_id: Student.find_by(user_id: @active_user.id).id).each do |grpld|
    #     @my_msg << GroupMessagetag.find_by(group_id: grpld.group_id).messagetag_id
    #   end
    # elsif Facultystaff.find_by(user_id: @active_user.id) != nil
    #   GroupAdvisor.where(facultystaff_id: Facultystaff.find_by(user_id: @active_user.id).id).each do |grpad|
    #     @my_msg << GroupMessagetag.find_by(group_id: grpld.group_id).messagetag_id
    #   end
    # end
    # Message.includes(:group).where(group: {id: GroupMember.where(student_id @active_user.id)})
    erb :announcements
  end
  
  post '/delete_message' do
    UserMessage.find_by(message_id: params[:msg], user_id: params[:id]).delete
    redirect '/announcements'
  end
  
  post '/read_message' do
    um = UserMessage.find_by(message_id: params[:msg], user_id: params[:id])
    old_status = um.unread
    um.update(unread: (not old_status))
    redirect '/announcements'
  end

  get '/messages' do
    if Student.find_by(user_id: @active_user.id) != nil #if user is a student
      stu = Student.find_by(user_id: @active_user.id)

      my_groups = Group.where(id: GroupMember.where(student_id: stu.id) + GroupLeader.where(student_id: stu.id))
      @group_msg = Message.where(id: MessageMessageTag.where(message_tag_id: MessageTag.where(id: GroupMessagetag.where(group_id: my_groups.select(:id)).select(:messagetag_id)).select(:id)).select(:message_id)).order(sent_at: :desc)
    elsif Facultystaff.find_by(user_id: @active_user.id) != nil
      fac = Facultystaff.find_by(user_id: @active_user.id)

      my_groups = Group.where(id: GroupAdvisor.where(facultystaff_id: fac.id))
      @group_msg = Message.where(id: MessageMessageTag.where(message_tag_id: MessageTag.where(id: GroupMessagetag.where(group_id: my_groups.select(:id)).select(:messagetag_id)).select(:id)).select(:message_id)).order(sent_at: :desc)
      
    end

  end
  ##END MESSAGES AND ANNOUNCEMENTS ##

  get '/new_event' do
    verify_user
    check_admin
    erb :new_event
  end

  get '/bw_events' do
    verify_user
    @events = BwEvent.all 
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

  ## USER MANAGEMENT ##
  post '/create_users' do #creates users based on text file submitted by user
    if params[:accountsFile] && params[:accountsFile][:filename] #only reads file if it exists & has been submitted
      file = params[:accountsFile][:tempfile].read
      accounts = file.split("\n") #breaks document into a list of account data
      accounts.each do |acct|
        data = acct.split(",") # splits individual student data into array
        #format: first name, last name, email, team color, grade, role, [admin]
        fname = data[0].strip
        lname = data[1].strip
        email = data[2].strip
        grade_level = Integer(data[4])
        role = data[5].downcase.strip
        
        searchingfor = User.find_by(firstname: fname, lastname: lname, email: email.downcase)

        if searchingfor == nil #user does not yet exist        
          team_id = BwTeam.find_by(team_color: data[3].downcase.strip).id
          # assigns an admin role to administrators
          if data.length > 6 and data[6].downcase.strip == "admin"
            is_admin = true
          else
            is_admin = false
          end
          
          #generates a default password in the format "gracedingholtonarms"
          password = (fname.downcase + lname.downcase + "holtonarms").to_s

          new_user = User.create(firstname: fname, lastname: lname, email: email.downcase, secret: password, team_id: team_id, is_admin: is_admin)

          #determine if the user is a student or a faculty/staff member and create the appropriate record
          if role == 'student'
            stu = Student.create(user_id: new_user.id, class_of: grade_level)
          else
            fac = Facultystaff.create(user_id: new_user.id, grade: grade_level)
          end
        end
      end
      redirect '/manage/manage_users'
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


    #determine class_of year based on selected grade and current date
    current_month = Date.today.month
    if current_month >= 1 and current_month <= 6
      senior_year = Date.today.year
    else
      senior_year = Date.today.year + 1
    end
    class_of = senior_year + (12 - Integer(grade))
    
    #generates a default password in the format "gdingholtonarms"
    password = (fname.downcase[0] + lname.downcase + "holtonarms").to_s

    new_user = User.create(firstname: fname, lastname: lname, 
                           email: email, secret: password, team_id: team_id, is_admin: is_admin, active: true)
    if role == "Student" 
      Student.create(user_id: new_user.id, class_of: Integer(class_of)) 
    else 
      Facultystaff.create(user_id: new_user.id, grade: Integer(grade))
    end
    redirect '/manage/manage_users'
  end

  get '/manage/manage_users' do
    verify_user
    check_admin
    all_users = User.all
    @all_by_groups = {}
    grades = Student.select(:class_of).distinct.sort
    grades.each do |grade|
      @all_by_groups[grade.class_of] = []
    end
    @all_by_groups[:facstaff] = []
    #figure out which users are students and put them together by grade level
    #and put all faculty and staff together
    @all_by_groups.keys.each do |grade|
      if grade.is_a? Integer
        @all_by_groups[grade] = User.where(id: Student.where(class_of: grade).select(:user_id)).order(lastname: :asc)
      else
        @all_by_groups[:facstaff] = User.where(id: Facultystaff.all.select(:user_id)).order(:lastname)
      end
    end
    # User.where(id: Student.all.select(:user_id)).where(grade: )
    # all_users.each do |user|
    #   stu = Student.find_by(user_id: user.id)
    #   fac = Facultystaff.find_by(user_id: user.id)
    #   if stu != nil
    #     @all_by_groups[stu.class_of].push(user)
    #   elsif fac != nil
    #     @all_by_groups[:facstaff].push(user)
    #   end
    # end
    erb :user_management
  end

  get '/manage/add_users' do
    verify_user
    check_admin
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
    erb :add_single_user
  end

  get '/manage/edit_user' do
    verify_user
    check_admin
    @use = User.find_by(id: params[:id])
    erb :edit_user
  end

  post '/manage/update_user' do
    user = User.find_by(id: params[:id])
    team = BwTeam.find_by(team_color: params[:team])
    is_admin = params[:is_admin] != nil ? true : false
    user.update(firstname: params[:fname], lastname: params[:lname], team_id: team.id, is_admin: is_admin)
    redirect '/manage/manage_users'
  end
  ## END USER MANAGEMENT ##

  get '/faculty_page' do
  # THIS IS NOT COMPLETE --- NEEDS TO CHECK IF USER IS FACULTY ??
    erb :faculty_page
  end

  get '/club_droppout' do
    verify_user
    gid = params["group_id"]
    group = Group.find_by(id: gid)
    student = Student.find_by(user_id: @active_user.id)
    member = GroupMember.find_by(student_id: student.id, group_id: gid)
    member.destroy
    if group.group_type == "sport"
      redirect '/my_sports'
    else
      redirect '/my_clubs'
    end
  end

  get '/today' do
    verify_user
    erb :day_schedule
  end

  ## GROUPS ##
  get '/my_clubs' do
    verify_user
    student = Student.find_by(user_id: @active_user.id)
    @leader_my_groups = []
    @member_my_groups = []
    @advisor_my_groups = []
    if student != nil
      leader = GroupLeader.where(student_id: student.id)
      leader.each do |ld|
        grp = Group.find_by(id: ld.group_id, active: true)
        if grp != nil
          if grp.group_type == "club" 
            @leader_my_groups.push(grp)
          end
        end
      end
      member = GroupMember.where(student_id: student.id)
      member.each do |mb|
        grp = Group.find_by(id: mb.group_id, active: true)
        if grp != nil
          if grp.group_type == "club"
            @member_my_groups.push(grp)
          end
        end
      end
    else
      fac = Facultystaff.find_by(user_id: @active_user.id)  
      group_adivsor = GroupAdvisor.where(facultystaff_id: fac.id)
      group_adivsor.each do |ga|
        grp = Group.find_by(id: ga.group_id, active: true)
        if grp != nil
          if grp.group_type == "club" 
            @advisor_my_groups.push(grp)
          end
        end
      end
    end
    
    erb :"groups/my_clubs"
  end
  
  get '/all_clubs' do
    verify_user
    @high_commitment = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "high commitment").id).order(name: :asc)
    @interest = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "interest").id).order(name: :asc)
    @affinity_groups = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "affinity group").id).order(name: :asc)
    erb :"groups/all_clubs"
  end

  get '/my_sports' do
    verify_user
    student = Student.find_by(user_id: @active_user.id)
    @leader_my_groups = []
    @member_my_groups = []
    @advisor_my_groups = []
    if student != nil
      leader = GroupLeader.where(student_id: student.id)
      leader.each do |ld|
        grp = Group.find_by(id: ld.group_id)
        if grp.group_type == "sport"
          @leader_my_groups.push(grp)
        end
      end
      member = GroupMember.where(student_id: student.id)
      member.each do |mb|
        grp = Group.find_by(id: mb.group_id)
        if grp.group_type == "sport"
          @member_my_groups.push(grp)
        end
      end
    else
      fac = Facultystaff.find_by(user_id: @active_user.id)  
      group_adivsor = GroupAdvisor.where(facultystaff_id: fac.id)
      group_adivsor.each do |ga|
        grp = Group.find_by(id: ga.group_id)
        if grp.group_type == "sport"
          @advisor_my_groups.push(grp)
        end
      end
    end
    erb :"groups/my_sports"
  end

  get '/all_sports' do
    verify_user
    # all_sports = Group.where(group_type: "sport", active: true).order(level_id: :asc, name: :asc)
    #iterates thru and sorts all sports based on season
    @fall_sports = Group.where(id: GroupSeason.where(season_id: Season.find_by(name: "Fall").id).select(:group_id)).order(level_id: :asc, name: :asc)
    @winter_sports = Group.where(id: GroupSeason.where(season_id: Season.find_by(name: "Winter").id).select(:group_id)).order(level_id: :asc, name: :asc)
    @spring_sports = Group.where(id: GroupSeason.where(season_id: Season.find_by(name: "Spring").id).select(:group_id)).order(level_id: :asc, name: :asc)
    # @spring_sports = []
    # #there should be a way to do this w/o hardcoding every season
    # all_sports.each do |sport|
    
    #   # if GroupSeason.find_by(group_id: sport.id).season_id == Season.find_by(name: "Fall").id
    #   #   @fall_sports << sport
    #   if GroupSeason.find_by(group_id: sport.id).season_id == Season.find_by(name: "Winter").id
    #     @winter_sports << sport
    #   elsif GroupSeason.find_by(group_id: sport.id).season_id == Season.find_by(name: "Spring").id
    #     @spring_sports << sport
    #   end  
    # end
    # @fall_sports1 = Group.where(GroupSeason.find_by(group_id: ))
    # @fall_sports = GroupSeason.where(season_id: Season.find_by(name: "Fall"))
    # @fall_sports = Group.where(GroupSeason.find_by(:group_id))
    # fall_sports_ids.each do |id|
    #   @fall_sports << Group.find(id)
    erb :"groups/all_sports"
  end

  get '/manage/manage_groups/add_group' do
    verify_user
    check_admin
    @group_types = []
    all_group_levels = GroupLevel.all
    all_group_levels.each do |level|
      @group_types.push(level)
    end

    @sports_seasons = Season.all
    
    #create hashes that have all of the necessary information for students by grade
    
    grades = Student.select(:class_of).distinct.sort()
    
    soph = grades[2].class_of
    jun = grades[1].class_of
    sen = grades[0].class_of

    @seniors = User.where(id: Student.where(class_of: sen).select(:user_id)).order(:lastname)
    @juniors = User.where(id: Student.where(class_of: jun).select(:user_id)).order(:lastname)
    @sophomores = User.where(id: Student.where(class_of: soph).select(:user_id)).order(:lastname)
    @freshmen = User.where(id: Student.where.not(class_of: [soph, jun, sen]).select(:user_id)).order(:lastname)
    
    
    erb :"groups/add_group"
  end
  
  
  post "/create_group" do
    #create the group from form data and put into the schema
    name = params[:groupName].downcase.strip
    groupF = Group.find_by(name: name)
    if groupF != nil
      erb :duplicate_club
    else
      group = Group.create(active: true, name: params[:groupName].downcase, description: params[:groupDescription], group_type: params[:typeSelection], level_id: Integer(params[:groupTypeDropdown]))
      #assign students to be leaders of the recently created group
      if params[:student_leader] != nil
        params[:student_leader].each do |leader_id|
          leader = GroupLeader.create(student_id: leader_id, group_id: group.id)
        end
      end
      #if the group is a sport, give it a season
      if params[:sportsSeason] != nil
        GroupSeason.create(group_id: group.id, season_id: params[:sportsSeason])
      end
      mt = MessageTag.create(recipient_tag: params[:groupName])
      GroupMessagetag.create(group_id: group.id, messagetag_id: mt.id)
      redirect '/manage/manage_groups'
    end
  end

  get '/manage/manage_groups' do
    verify_user
    check_admin
    @all_sports = Group.where(group_type: "sport", active: true).order(level_id: :asc, name: :asc) 
    @all_clubs = Group.where(group_type: "club", active: true).order(level_id: :asc, name: :asc)
    @archived_groups = Group.where(active: false).order(group_type: :asc, level_id: :asc, name: :asc)
    erb :"groups/group_management"
  end

  get "/manage/edit_group" do
    verify_user
    check_admin
    @group = Group.find(params[:id])
    erb :"groups/edit_group"
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
    msgtg = MessageTag.find_by(recipient_tag: group.name.titleize)
    msgtg.update(active: false)
    redirect '/manage/manage_groups'
  end 

  post "/manage/restore_group" do
    group = Group.find(params[:id])
    group.update(active: true)
    msgtg = MessageTag.find_by(recipient_tag: group.name.titleize)
    msgtg.update(active: true)
    # puts group.name
    redirect '/manage/manage_groups'
  end 

  post "/manage/trash_group" do
    group = Group.find(params[:id])
    if not group.active
      if group.group_type =="club"
        GroupAdvisor.destroy_by(group_id: group.id)
        GroupLeader.destroy_by(group_id: group.id)
        GroupMeeting.destroy_by(group_id: group.id)
        GroupMember.destroy_by(group_id: group.id)
        # THIS LINE EVENTUALLY NEEDS TO BE UNCOMMENTED
        # WHEN WE CREATE THE GROUP MESSAGE TAG ASSOCIATION
        GroupMessagetag.destroy_by(group_id: group.id)
        
      elsif group.group_type == "sport"
        GroupAdvisor.destroy_by(group_id: group.id)
        GroupLeader.destroy_by(group_id: group.id)
        GroupMeeting.destroy_by(group_id: group.id)
        GroupMember.destroy_by(group_id: group.id)
        GroupMessagetag.destroy_by(group_id: group.id)
        GroupSeason.destroy_by(group_id: group.id)
        Game.destroy_by(team_id: group.id)
      end
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
    
    erb :"groups/add_batch_group_members"
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
    grp = Group.find_by(id: group_id)
    if grp.type == "club"
      redirect '/all_clubs/' + grp.name.gsub(" ", "_")
    elsif grp.type == "sport"
      redirect '/all_sports/' + grp.name.gsub(" ", "_")
    else
      redirect '/manage/manage_groups' 
    end
  end

  get '/all_clubs/:club_name/add_member' do
    verify_user
    club = params['club_name']
    underscore = "_"
    club.gsub!(underscore, " ")
    club.downcase!
    @current_group = Group.find_by(name: club)
  
    is_leader = false
    if Student.find_by(user_id: @active_user.id) != nil and GroupLeader.find_by(group_id: @current_group.id, student_id: Student.find_by(user_id: @active_user.id)) != nil
      is_leader = true
    end
    if is_leader or @active_user.is_admin
      @all_students = {}
      Student.select(:class_of).distinct.order(:class_of).each do |grade|
        grade = grade.class_of
        puts "hello"
        @all_students[grade] = User.where(id: Student.where(class_of: grade).select(:user_id)).order(:lastname) 
        @all_students[grade].each do |person|
          puts person.firstname
        end
      end
      # puts @all_students
      
      erb :"groups/add_group_member"
    else
      erb :error
    end
    # redirect '/'
  end

  get '/all_sports/:sport/add_member' do
    verify_user
    sport = params[:sport]
    underscore = "_"
    sport.gsub!(underscore, " ")
    sport.downcase!
    @current_group = Group.find_by(name: sport)
  
    is_leader = false
    if Student.find_by(user_id: @active_user.id) != nil and GroupLeader.find_by(group_id: @current_group.id, student_id: Student.find_by(user_id: @active_user.id)) != nil
      is_leader = true
    end
    if is_leader or @active_user.is_admin
      @all_students = {}
      Student.select(:class_of).distinct.order(:class_of).each do |grade|
        grade = grade.class_of
        puts "hello"
        @all_students[grade] = User.where(id: Student.where(class_of: grade).select(:user_id)).order(:lastname) 
        @all_students[grade].each do |person|
          puts person.firstname
        end
      end
      # puts @all_students
      
      erb :"groups/add_group_member"
    else
      erb :error
    end
  end

  post '/adding_members/:club_name' do
    verify_user
    club = params['club_name']
    underscore = "_"
    club.gsub!(underscore, " ")
    club.downcase!
    @current_group = Group.find_by(name: club)
    selected_users = params[:user]
    selected_users.each do |st|
      split_name = st.split(", ")
      user = User.find_by(firstname: split_name[1], lastname: split_name[0])
      student = Student.find_by(user_id: user.id)
      if GroupMember.find_by(student_id: student.id, group_id: @current_group.id) == nil
        if GroupLeader.find_by(student_id: student.id, group_id: @current_group.id) == nil
          GroupMember.create(student_id: student.id, group_id: @current_group.id)
        end
      end
    end

    if @current_group.group_type == "club"
      redirect '/all_clubs/'+@current_group.name.gsub(" ", "_")
    elsif @current_group.group_type == "sport"
      redirect '/all_sports/'+ @current_group.name.gsub(" ", "_")
    else
      # puts @current_group.group_type + 'error'
      redirect '/error'

    end
  end

  get '/all_clubs/:club_name' do
    verify_user
    club = params[:club_name]
    underscore = "_"
    club.gsub!(underscore, " ")
    club.downcase!
 
    @current_group = Group.find_by(name: club)
    if @current_group != nil and @current_group.active and @current_group.group_type == "club"
      @club_members = []
      @club_leaders = []
      @club_members = User.where(id: Student.where(id: GroupMember.where(group_id: @current_group.id).select(:student_id)).select(:user_id)).order(:class_of, :lastname)
      @club_leaders = User.where(id: Student.where(id: GroupLeader.where(group_id: @current_group.id).select(:student_id)).select(:user_id)).order(class_of: :asc, lastname: :desc)
      leaders = GroupLeader.where(group_id: @current_group.id)
      if GroupAdvisor.where(group_id: @current_group.id) != nil
        @adv = User.where(id: Facultystaff.where(id: GroupAdvisor.where(group_id: @current_group.id).select(:facultystaff_id)).select(:user_id))
      end
      all_meetings = GroupMeeting.where(group_id: @current_group.id)
      puts all_meetings
      @meetings = []
      all_meetings.each do |meeting|
        if meeting.event_date > Time.now()
          @meetings.push(meeting)
        end
        @meetings = @meetings.sort_by {|meeting| meeting.event_date}
      end

      @images = {}
      n = 1
      club.gsub!(" ", "_")
      puts File.dirname(__FILE__) + '/public/clubs/'+ club + n.to_s + '.jpg'
      image_exists = File.file?(File.dirname(__FILE__) + '/public/clubs/'+ club + n.to_s + '.jpg')
      puts image_exists
      while image_exists
        @images[n] = '/clubs/'+ club + n.to_s + '.jpg'
        n += 1
        image_exists = File.file?(File.dirname(__FILE__) + '/public/clubs/'+ club + n.to_s + '.jpg') #checks if file exists
        
      end
      
      erb :"groups/club_page"
    else
      erb :error
    end
  end

  get '/all_clubs/:club_name/manage_members' do
    verify_user
    club = params[:club_name].gsub!("_", " ")
    @current_group = Group.find_by(name: club)

    if GroupMember.where(group_id: @current_group.id) != nil
      @members = User.where(id: (Student.where(id: GroupMember.where(group_id: @current_group.id).select(:student_id)).select(:user_id)))
    end
    if GroupLeader.where(group_id: @current_group.id) != nil
      @leaders = User.where(id: (Student.where(id: GroupLeader.where(group_id: @current_group.id).select(:student_id)).select(:user_id)))
    end

    erb :'groups/manage_members'
  end

  get '/all_sports/:sport/manage_members' do
    verify_user
    grp = params[:sport].gsub!("_", " ")
    @current_group = Group.find_by(name: grp)

    if GroupMember.where(group_id: @current_group.id) != nil
      @members = User.where(id: (Student.where(id: GroupMember.where(group_id: @current_group.id).select(:student_id)).select(:user_id)))
    end
    if GroupLeader.where(group_id: @current_group.id) != nil
      @leaders = User.where(id: (Student.where(id: GroupLeader.where(group_id: @current_group.id).select(:student_id)).select(:user_id)))
    end

    erb :'groups/manage_members'
  end

  post '/managing_members/:group_name' do
    group = params['group_name'].gsub!('_', " ")
    group.downcase!
    @current_group = Group.find_by(name: group)
    selected_users = params[:user]
    students = Student.all()

    if selected_users != nil
      selected_users.each do |st|
        split_name = st.split(", ")
        member = GroupMember.find_by(student_id: Student.find_by(user_id: User.find_by(firstname: split_name[1], lastname: split_name[0]).id).id, group_id: @current_group.id)
        if member != nil
          member.destroy
        end

        if params[:task] == "promote"
          GroupLeader.create(student_id: Student.find_by(user_id: User.find_by(firstname: split_name[1], lastname: split_name[0]).id).id, group_id: @current_group.id)
        end
      end
    end  

    redirect '/all_clubs/' + params['group_name'].to_s.gsub(" ", "_") + '/manage_members'
  end

  post '/managing_leaders/:group_name' do
    group = params['group_name'].gsub!('_', " ")
    group.downcase!
    @current_group = Group.find_by(name: group)
    selected_users = params[:user]
    students = Student.all()

    if selected_users != nil
      selected_users.each do |st|
        split_name = st.split(", ")
        leader = GroupLeader.find_by(student_id: Student.find_by(user_id: User.find_by(firstname: split_name[1], lastname: split_name[0]).id).id, group_id: @current_group.id)
        if leader != nil
          leader.destroy
        end

        if params[:task] == "demote"
          puts params[:task]
          GroupMember.create(student_id: Student.find_by(user_id: User.find_by(firstname: split_name[1], lastname: split_name[0]).id).id, group_id: @current_group.id)
        end
      end
    end  

    redirect '/all_clubs/' + params['group_name'].to_s.gsub(" ", "_") + '/manage_members'
  end



  get '/all_sports/:sport_name' do
    verify_user
    sport = params['sport_name']
    sport.gsub!('_', " ")
    @current_group = Group.find_by(name: sport)
    if @current_group.active and @current_group.group_type == "sport"
      @record = Game.where(team_id: @current_group.id).order(date: :asc)
      unordered_roster = GroupMember.where(group_id: @current_group.id).select(:student_id)
      # puts Student.where(GroupMember.where(group_id: @current_group.id).select(:student_id)
      @roster = User.where(id: (Student.where(id: GroupMember.where(group_id: @current_group.id).select(:student_id)).select(:user_id))).order(firstname: :asc)
      @coaches = User.where(id: (Facultystaff.where(id: GroupAdvisor.where(group_id: @current_group.id).select(:facultystaff_id)).select(:user_id))).order(firstname: :asc)
      @captains = User.where(id: (Student.where(id: GroupLeader.where(group_id: @current_group.id).select(:student_id)).select(:user_id))).order(firstname: :asc)
      is_leader = Student.find_by(user_id: @active_user.id) != nil && GroupLeader.find_by(group_id: @current_group.id, student_id: Student.find_by(user_id: @active_user.id).id) != nil
      puts GroupLeader.find_by(group_id: @current_group.id, student_id: Student.find_by(user_id: @active_user.id).id) != nil  
      is_advisor = Facultystaff.find_by(user_id: @active_user.id) != nil && GroupAdvisor.find_by(group_id: @current_group.id, facultystaff_id: Facultystaff.find_by(user_id: @active_user.id).id) != nil
      puts is_leader
      puts is_advisor
      @leader = @active_user.is_admin or is_leader or is_advisor
      @wins = 0
      @losses = 0
      Game.where(team_id: @current_group.id).each do |game|
        puts game.home_score
        if not(game.result.blank? and game.home_score.blank? and game.away_score.blank?)
          if game.result.downcase == 'win' or game.home_score > game.away_score
            @wins += 1
          elsif game.result.downcase == 'loss' or game.home_score < game.away_score
            @losses += 1
          end
        end
      end
      erb :"groups/sports_page"
    else
      erb :error
    end
  end

  get '/all_clubs/:name/add_advisor' do
    verify_user
    grp_name = params[:name].gsub("_", " ")
    @grp = Group.find_by(name: grp_name)
    # is_leader = Student.find_by(user_id: @active_user.id) != nil and GroupLeader.find_by(group_id: @grp.id, student_id: Student.find_by(user_id: @active_user.id).id) != nil
    is_leader = false
    if Student.find_by(user_id: @active_user.id) != nil and GroupLeader.find_by(group_id: @grp.id, student_id: Student.find_by(user_id: @active_user.id).id) != nil
      is_leader = true
    end
    is_advisor = false
    if Facultystaff.find_by(user_id: @active_user.id) != nil and GroupAdvisor.find_by(group_id: @grp.id, facultystaff_id: Facultystaff.find_by(user_id: @active_user.id).id) != nil
      is_advisor = true
    end 
    if @active_user.is_admin or is_leader or is_advisor
      @adv = Facultystaff.where(id: GroupAdvisor.where(group_id: @grp.id).order(:id).select(:facultystaff_id))
      erb :"groups/add_advisor"
    else
      erb :error
    end
  end

  get '/all_sports/:name/add_coach' do
    verify_user
    grp_name = params[:name].gsub("_", " ")
    @grp = Group.find_by(name: grp_name)
    is_leader = Student.find_by(user_id: @active_user.id) != nil and GroupLeader.find_by(group_id: @grp.id, student_id: Student.find_by(user_id: @active_user.id).id)
    is_advisor = Facultystaff.find_by(user_id: @active_user.id) != nil and GroupAdvisor.find_by(group_id: @grp.id, facultystaff_id: Facultystaff.find_by(user_id: @active_user.id).id)
    if @active_user.is_admin or is_leader or is_advisor
      @adv = Facultystaff.where(id: GroupAdvisor.where(group_id: @grp.id).order(:id).select(:facultystaff_id))
      erb :"groups/add_advisor"
    else
      erb :error
    end
  end

  post '/add_advisor' do
    grp = Group.find_by(id: params[:id])
    # adv = User.find_by(id: params[:advisors].to_i)
    
    if params[:commit] == "repeat"
      if params[:advisors]
        fac = Facultystaff.find_by(user_id: params[:advisors].to_i)
        if GroupAdvisor.find_by(group_id: grp.id, facultystaff_id: fac.id) == nil
          GroupAdvisor.create(group_id: grp.id, facultystaff_id: fac.id)
        end
      end
      if grp.group_type == "club"
        adv = "advisor"
      else
        adv = "coach"
      end
      redirect '/all_' + grp.group_type + 's/' + grp.name.gsub(" ", "_") + '/add_' + adv
    elsif params[:commit] == "submit"
      if params[:advisors]
        fac = Facultystaff.find_by(user_id: params[:advisors].to_i)
        if GroupAdvisor.find_by(group_id: grp.id, facultystaff_id: fac.id) == nil
          GroupAdvisor.create(group_id: grp.id, facultystaff_id: fac.id)
        end
      end
      redirect '/all_' + grp.group_type + 's/' + grp.name.gsub(" ", "_")
    elsif params[:commit].include? "delete" #if the action is to delete
      n = params[:commit].sub("delete", "").to_i
      GroupAdvisor.find_by(facultystaff_id: n, group_id: grp.id).destroy
      redirect '/all_' + grp.group_type + 's/' + grp.name.gsub(" ", "_") + '/add_advisor'
    end
  end

  post '/delete_advisor' do
    grp = Group.find_by(id: params[:id])
    n = params[:commit].to_i
    GroupAdvisor.find_by(facultystaff_id: n, group_id: grp.id).destroy
    if grp.group_type == "club"
      adv = "advisor"
    else
      adv = "coach"
    end
    redirect '/all_' + grp.group_type + 's/' + grp.name.gsub(" ", "_") + '/add_' + adv
  end

  get '/all_clubs/:name/add_meeting' do
    verify_user
    name = params[:name].gsub("_", " ")
    @current_group = Group.find_by(name: name)
    if GroupLeader.find_by(group_id: @current_group.id, student_id: @active_user.id) != nil
      erb :"groups/add_club_meeting"
    else
      erb :error
    end
  end

  post '/push_club_meeting' do
    verify_user
    #still need to build frontend 
    location = params[:location]
    date = params[:date].to_datetime
    id = params[:id].to_i #need to specifically pass as ID
    desc = params[:description]
    meeting = GroupMeeting.create(location: location, event_date: date, group_id: id.to_i, description: desc)
    grp = Group.find_by(id: id)
    # sends a message to all applicable members
    subj = "New " + grp.name.titleize + " Meeting: " + date.strftime("%B %-d")
    content = @active_user.firstname + " " + @active_user.lastname + " added a " + 
              grp.name.titleize + " meeting at " + date.strftime("%l:%M %P on %A, %B %-d") + " in " + location + " \n\r Description: " + desc
    
    time = Time.now
    time = DateTime.new(time.year, time.month, time.day, time.strftime("%H").to_i + (time.strftime("%z").to_i/100), time.min, time.sec, time.zone)
    msg = Message.create(subject: subj, sent_at: time, content: content, author_id: @active_user.id)
    msgtg = MessageTag.find_by(id: GroupMessagetag.find_by(group_id: grp.id).messagetag_id)
    MessageMessageTag.create(message_id: msg.id, message_tag_id: msgtg.id)
    
    memb = Student.where(id: GroupMember.where(group_id: grp.id).select(:student_id)) + Student.where(id: GroupLeader.where(group_id: grp.id).select(:student_id))
    memb.each do |stu|
      if not UserMessage.where(user_id: stu.user_id, message_id: msg.id).exists?
        UserMessage.create(user_id: stu.user_id, message_id: msg.id)
      end
    end
    
    fac = Facultystaff.where(id: GroupAdvisor.where(group_id: grp.id).select(:facultystaff_id))
    fac.each do |fs|
      if not UserMessage.where(user_id: fs.user_id, message_id: msg.id).exists?
        UserMessage.create(user_id: fs.user_id, message_id: msg.id)
      end
    end
    
    redirect "/meetings"
    # redirect '/post_message?subject=' + subj + '&content=' + content + '&author= ' + @active_user.id.to_s + '&tag=' + msgtg
  end

  get '/all_sports/:name/add_game' do
    verify_user
    name = params[:name].gsub("_", " ")
    @current_group = Group.find_by(name: name)
    erb :"groups/add_game"
  end

  post '/push_game_record' do
    name = params[:name]
    id = params[:id].to_i
    date = params[:date].to_datetime
    home = params[:advantage]
    h_score = params[:hscore]
    a_score = params[:ascore]
    details = params[:details]
    result = params[:result]
    id = params[:id].to_i 
    Game.create(name: name, team_id: id, date: date, advantage: home, home_score: h_score, away_score: a_score, details: details, result: result, status: true)
    redirect "/all_sports/"+ Group.find_by(id: id).name.gsub(" ", "_").to_s
  end
  
  get '/all_sports/:name/edit' do #edit game records
    verify_user
    grp = Group.find_by(name: params[:name].downcase.gsub("_", " "))
    is_leader = Student.find_by(user_id: @active_user.id) != nil and GroupLeader.find_by(group_id: grp.id, student_id: Student.find_by(user_id: @active_user.id).id)
    is_advisor = Facultystaff.find_by(user_id: @active_user.id) != nil and GroupAdvisor.find_by(group_id: grp.id, facultystaff_id: Facultystaff.find_by(user_id: @active_user.id).id)
    if is_leader or is_advisor or @active_user.is_admin
      @game = Game.find_by(id: params[:id].to_i)
      erb :"groups/edit_game"
    else
      erb :error
    end
  end

  post '/edit_game' do
    verify_user
    game = Game.find_by(id: params[:id].to_i)
    name = params[:name]
    id = params[:id]
    date = params[:date].to_datetime
    home = params[:advantage]
    h_score = params[:hscore]
    a_score = params[:ascore]
    details = params[:details]
    result = params[:result]
    sport = Group.find(game.team_id)
    id = params[:id].to_i 
    
    if params[:cancel] == 'on'
      status = false
      subj = sport.name.titleize + " Game Canceled: " + date.strftime("%B %-d")
      content = @active_user.firstname + " " + @active_user.lastname + " canceled the " + 
                sport.name.titleize + " game at " + date.strftime("%l:%M %P on %A, %B %-d") 
      
      time = Time.now
      time = DateTime.new(time.year, time.month, time.day, time.strftime("%H").to_i + (time.strftime("%z").to_i/100), time.min, time.sec, time.zone)
      msg = Message.create(subject: subj, sent_at: time, content: content, author_id: @active_user.id)
      msgtg = MessageTag.find_by(id: GroupMessagetag.find_by(group_id: sport.id).messagetag_id)
      MessageMessageTag.create(message_id: msg.id, message_tag_id: msgtg.id)
      
      memb = Student.where(id: GroupMember.where(group_id: sport.id).select(:student_id)) + Student.where(id: GroupLeader.where(group_id: sport.id).select(:student_id))
      memb.each do |stu|
        if not UserMessage.where(user_id: stu.user_id, message_id: msg.id).exists?
          UserMessage.create(user_id: stu.user_id, message_id: msg.id)
        end
      end
      
      fac = Facultystaff.where(id: GroupAdvisor.where(group_id: sport.id).select(:facultystaff_id))
      fac.each do |fs|
        if not UserMessage.where(user_id: fs.user_id, message_id: msg.id).exists?
          UserMessage.create(user_id: fs.user_id, message_id: msg.id)
        end
      end
    else
      status = true
    end
    
    game.update(status: status, name: name, date: date, advantage: home, 
                home_score: h_score, away_score: a_score, details: details, result: result)

    redirect "/all_sports/"+ sport.name.gsub(" ", "_").to_s
  end

  post '/delete_game' do
    verify_user
    game = Game.find_by(id: params[:id])
    sport = Group.find(game.team_id)
    
    date = game.date
    subj = sport.name.titleize + " Game Canceled: " + date.strftime("%B %-d")
    content = @active_user.firstname + " " + @active_user.lastname + " canceled the " + 
              sport.name.titleize + " game at " + date.strftime("%l:%M %P on %A, %B %-d") 
    
    time = Time.now
    time = DateTime.new(time.year, time.month, time.day, time.strftime("%H").to_i + (time.strftime("%z").to_i/100), time.min, time.sec, time.zone)
    msg = Message.create(subject: subj, sent_at: time, content: content, author_id: @active_user.id)
    msgtg = MessageTag.find_by(id: GroupMessagetag.find_by(group_id: sport.id).messagetag_id)
    MessageMessageTag.create(message_id: msg.id, message_tag_id: msgtg.id)
    
    memb = Student.where(id: GroupMember.where(group_id: sport.id).select(:student_id)) + Student.where(id: GroupLeader.where(group_id: sport.id).select(:student_id))
    memb.each do |stu|
      if not UserMessage.where(user_id: stu.user_id, message_id: msg.id).exists?
        UserMessage.create(user_id: stu.user_id, message_id: msg.id)
      end
    end
    
    fac = Facultystaff.where(id: GroupAdvisor.where(group_id: sport.id).select(:facultystaff_id))
    fac.each do |fs|
      if not UserMessage.where(user_id: fs.user_id, message_id: msg.id).exists?
        UserMessage.create(user_id: fs.user_id, message_id: msg.id)
      end
    end

    game.delete
    redirect "/all_sports/"+ sport.name.gsub(" ", "_").to_s
  end

  get '/all_sports/:sport_name/add_image' do
    verify_user
    # restrict to admins/leaders
    sport = params['sport_name']
    sport.gsub!('_', " ")
    @current_group = Group.find_by(name: sport)
    if @current_group.active
      erb :"groups/add_sport_image"
    else
      erb :error
    end
  end

  post '/upload_sport_image' do
    id = params[:id]
    sport = Group.find(id)
    sport_name = sport.name.gsub(" ", "_")

    photo = params[:imageUpload][:tempfile].read
    # path = Pathname.new('../public/' + sport_name + ".txt")
    path = File.dirname(__FILE__) + '/public/sports/'+sport_name + '.jpg'
    File.open(path, 'wb') do |f|
      f.write(photo)
    end
    redirect '/all_sports/' + sport_name
  end

  get '/all_clubs/:club_name/edit' do
    verify_user
    groupname=params["club_name"].downcase
    @updatepath="/update_club?name="+params[:club_name].to_s
    @groupedit=Group.find_by(name: groupname.gsub("_"," "))
    
    @images = {}
    n = 1
    image_exists = File.file?(File.dirname(__FILE__) + '/public/clubs/'+ groupname + n.to_s + '.jpg')
    
    while image_exists
      @images[n] = '/clubs/'+ groupname + n.to_s + '.jpg'
      n += 1
      image_exists = File.file?(File.dirname(__FILE__) + '/public/clubs/'+ groupname + n.to_s + '.jpg') #checks if file exists
    end
    erb :"groups/edit_club_page"
  end

  post '/update_club' do 
    groupname=params["name"].downcase.gsub("_"," ")
    groupedit=Group.find_by(name: groupname)
    #if they are totally SUBMITTED
    if params[:commit] == "submit" 
      groupedit.update(description: params["description"].strip) #commits descript 
      if params[:imageFile] #adds a new image file if necessary
        photo = params[:imageFile][:tempfile].read
        image_exists = true
        n = 0
        while image_exists
          n += 1
          # puts File.file?(File.dirname(__FILE__) + '/public/clubs/'+params[:name] + n.to_s + '.jpg')
          image_exists = File.file?(File.dirname(__FILE__) + '/public/clubs/'+params[:name] + n.to_s + '.jpg') #checks if file exists
        end
        
        path = File.dirname(__FILE__) + '/public/clubs/'+params[:name] + n.to_s + '.jpg'
        File.open(path, 'wb') do |f|
          f.write(photo)
        end
      end
      redirect "/all_clubs/" + params["name"]
    # for previewing images & adding multiple
    elsif params[:commit] == "preview"
      club_name = params[:name].gsub("_", " ")
      club = Group.find_by(name: club_name)

      if params[:imageFile]
        photo = params[:imageFile][:tempfile].read
        image_exists = true
        n = 0
        while image_exists #finds last image in line and appends a new one
          n += 1
          puts File.file?(File.dirname(__FILE__) + '/public/clubs/'+params[:name] + n.to_s + '.jpg')
          image_exists = File.file?(File.dirname(__FILE__) + '/public/clubs/'+params[:name] + n.to_s + '.jpg') #checks if file exists
        end
        
        path = File.dirname(__FILE__) + '/public/clubs/'+params[:name] + n.to_s + '.jpg'
        File.open(path, 'wb') do |f|
          f.write(photo)
        end
      end
      redirect "/all_clubs/" + params["name"] + "/edit"
    #for deleting photos
    elsif params[:commit].include? "delete" #if the action is to delete
      puts params[:commit]
      n = params[:commit].sub("delete", "").to_i #first strip to which photo number we're deleting
      #sets image exists to true for the image we're trying to delete
      image_exists = File.file?(File.dirname(__FILE__) + '/public/clubs/'+ params[:name]+ (n+1).to_s + '.jpg')
      while image_exists
        current_img = File.open(File.dirname(__FILE__) + '/public/clubs/'+ params[:name]+ n.to_s + '.jpg')
        replacement_img = File.open(File.dirname(__FILE__) + '/public/clubs/'+ params[:name]+ (n+1).to_s + '.jpg')
        File.open(current_img, 'wb') do |f|
          f.write(File.read(replacement_img))
        end
        n+=1 #looks for the next image in line to replace it with 
        #stops once the next image does not exist
        next_img = File.dirname(__FILE__) + '/public/clubs/'+ params[:name]+ (n+1).to_s + '.jpg'
        image_exists = File.file?(next_img)
      end
      File.delete(File.dirname(__FILE__) + '/public/clubs/'+ params[:name]+ (n).to_s + '.jpg')
      redirect "/all_clubs/" + params["name"] + "/edit"
    end
  end 

  get '/meetings' do 
    verify_user

    @groups = Group.all
    my_group_list = GroupLeader.where(student_id: @active_user.id) + GroupMember.where(student_id: @active_user.id)
    @my_groups = []
    @meetings = GroupMeeting.where('event_date >= ?', Time.now.midnight).order(:event_date)

    # @my_groups = Group.where(id: GroupLeader.where(student_id: @active_user.id).select(:group_id) + GroupMember.where(student_id: @active_user.id).select(:group_id))
    my_group_list.each do |group|
      @my_groups.push(@groups.find_by(id: group.group_id).id)
    end

    @meetings = @meetings.sort_by {|meeting| meeting.event_date}

    erb :"groups/meetings"
  end

  get '/meetings/edit' do
    verify_user
    @meeting = GroupMeeting.find_by(id: params[:id])
    if GroupLeader.find_by(group_id: @meeting.group_id, student_id: @active_user.id) != nil
      erb :"groups/edit_meeting"
    else
      erb :error
    end
  end

  post '/update_meeting' do
    verify_user
    meeting = GroupMeeting.find_by(id: params[:id])
    
    location = params[:location]
    date = params[:date].to_datetime #calendar on the frontend
    desc = params[:desc]
    meeting.update(location: location, event_date: date, description: desc) # this one - should be an edit 
    
    
    redirect '/meetings'
  end

  post '/delete_meeting' do
    verify_user
    meeting = GroupMeeting.find_by(id: params[:id])
    date = meeting.event_date
    grp = Group.find_by(id: meeting.group_id)
    subj = grp.name.titleize + " Meeting Canceled: " + date.strftime("%B %-d")
    content = @active_user.firstname + " " + @active_user.lastname + " canceled the " + 
              grp.name.titleize + " meeting at " + date.strftime("%l:%M %P on %A, %B %-d") 
    
    time = Time.now
    time = DateTime.new(time.year, time.month, time.day, time.strftime("%H").to_i + (time.strftime("%z").to_i/100), time.min, time.sec, time.zone)
    msg = Message.create(subject: subj, sent_at: time, content: content, author_id: @active_user.id)
    msgtg = MessageTag.find_by(id: GroupMessagetag.find_by(group_id: grp.id).messagetag_id)
    MessageMessageTag.create(message_id: msg.id, message_tag_id: msgtg.id)
    
    memb = Student.where(id: GroupMember.where(group_id: grp.id).select(:student_id)) + Student.where(id: GroupLeader.where(group_id: grp.id).select(:student_id))
    memb.each do |stu|
      if not UserMessage.where(user_id: stu.user_id, message_id: msg.id).exists?
        UserMessage.create(user_id: stu.user_id, message_id: msg.id)
      end
    end
    
    fac = Facultystaff.where(id: GroupAdvisor.where(group_id: grp.id).select(:facultystaff_id))
    fac.each do |fs|
      if not UserMessage.where(user_id: fs.user_id, message_id: msg.id).exists?
        UserMessage.create(user_id: fs.user_id, message_id: msg.id)
      end
    end
    meeting.destroy
    redirect '/meetings'
  end

  get '/games' do
    verify_user 
    
    @allgames=Game.where("date>=?", Date.today).order(:date)
    erb :'groups/games'
  end 

  ##########################################
end


