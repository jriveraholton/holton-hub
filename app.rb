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

  get '/student' do
    # NEED TO ONLY AUTHORIZE IF STUDENT!!!!
    erb :student
  end

  ## MESSAGES and ANNOUNCEMENTS ##
  get '/send_message' do
    verify_user
    @groups = [] #list of message tag objects
    if @active_user.is_admin
      @groups = MessageTag.all
    elsif Student.where(user_id: @active_user.id) != nil #if user is a student
      stu = Student.find_by(user_id: @active_user.id)
      if GroupLeader.where(student_id: stu.id) != nil #if user is a group leader        
        GroupLeader.where(student_id: stu.id).each do |grp| #iterates thru groupleader objects
          @groups << MessageTag.find(GroupMessagetag.find_by(group_id: grp.group_id).messagetag_id)
        end
      end
    elsif Facultystaff.where(user_id: @active_user.id) != nil
      fac = Facultystaff.find_by(user_id: @active_user.id)
      if GroupAdvisor.where(facultystaff_id: fac.id) != nil #if user is a club advisor
        GroupAdvisor.find_by(facultystaff_id: fac.id).each do |grp| #iterates thru groupleader objects
          @groups << MessageTag.find(GroupMessagetag.find_by(group_id: grp.group_id).messagetag_id)
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
        Student.where(class_of: tag[-4...-1].to_i).each do |stu|
          if not UserMessage.where(user_id: stu.user_id, message_id: msg.id).exists?
            UserMessage.create(user_id: stu.user_id, message_id: msg.id)
          end
        end
        #still need to do faculty staff
      else
        grp = Group.find_by(id: GroupMessagetag.find_by(messagetag_id: mt.id).group_id)
        
        memb = Student.where(id: GroupMember.where(group_id: grp.id)+ GroupLeader.where(group_id: grp.id))
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


    if Student.find_by(user_id: @active_user.id) != nil #if user is a student
      stu = Student.find_by(user_id: @active_user.id)
      mt = MessageTag.find_by(recipient_tag: "Class of " + stu.class_of.to_s)
    elsif Facultystaff.find_by(user_id: @active_user.id) != nil
      fac = Facultystaff.find_by(user_id: @active_user.id)
      grades = Student.select(:class_of).distinct.sort.to_a
      if fac.grade == 12
        gr = grades[0].class_of
      elsif fac.grade == 11
        gr = grades[1].class_of
      elsif fac.grade == 10
        gr = grades[2].class_of
      else
        gr = grades[3].class_of
      end
      mt = MessageTag.find_by(recipient_tag: "Class of "+ gr.to_s)
    end
    # @all_msg = Message.where(id: MessageMessageTag.where(message_tag_id: [mt.id, MessageTag.find_by(recipient_tag: "Upper School").id]).select(:message_id)).order(sent_at: :desc)
    
    @all_msg = Message.where(id: UserMessage.where(user_id: @active_user.id).select(:message_id)).order(sent_at: :desc)

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

  get '/messages' do
    if Student.find_by(user_id: @active_user.id) != nil #if user is a student
      stu = Student.find_by(user_id: @active_user.id)

      my_groups = Group.where(id: GroupMember.where(student_id: stu.id) + GroupLeader.where(student_id: stu.id))
      # puts my_groups
      @group_msg = Message.where(id: MessageMessageTag.where(message_tag_id: MessageTag.where(id: GroupMessagetag.where(group_id: my_groups.select(:id)).select(:messagetag_id)).select(:id)).select(:message_id)).order(sent_at: :desc)
    elsif Facultystaff.find_by(user_id: @active_user.id) != nil
      fac = Facultystaff.find_by(user_id: @active_user.id)

      my_groups = Group.where(id: GroupAdvisor.where(facultystaff_id: fac.id))
      # puts my_groups
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
        
        if User.find_by(email: email) == nil #user does not yet exist        
          team_id = BwTeam.find_by(team_color: data[3].downcase.strip).id
          # assigns an admin role to administrators
          if data.length > 6 and data[6].downcase.strip == "admin"
            is_admin = true
          else
            is_admin = false
          end
          
          #generates a default password in the format "gracedingholtonarms"
          password = (fname.downcase + lname.downcase + "holtonarms").to_s

          new_user = User.create(firstname: fname, lastname: lname, 
                                 email: email, secret: password, team_id: team_id, is_admin: is_admin)

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

    
    #generates a default password in the format "gdingholtonarms"
    password = (fname.downcase[0] + lname.downcase + "holtonarms").to_s

    new_user = User.create(firstname: fname, lastname: lname, 
                           email: email, secret: password, team_id: team_id, is_admin: is_admin)
    if role == "Student" 
      Student.create(user_id: new_user.id, grade: Integer(grade)) 
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
    puts @all_by_groups
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
    user.update(firstname: params[:fname], lastname: params[:lname], team_id: team.id)
    redirect '/manage/manage_users'
  end
  ## END USER MANAGEMENT ##

  get '/faculty_page' do
  # THIS IS NOT COMPLETE --- NEEDS TO CHECK IF USER IS FACULTY ??
    erb :faculty_page
  end

  get '/club_droppout' do
    erb :club_droppout
  end


  get '/today' do
    verify_user
    erb :day_schedule
  end

  ## GROUPS ##
  get '/my_clubs' do
    verify_user
    student = Student.find_by(user_id: @active_user.id)
    @my_groups = []

    if student != nil
      leader = GroupLeader.where(student_id: student.id)
      leader.each do |ld|
        grp = Group.find_by(id: ld.group_id, active: true)
        if grp != nil
          if grp.group_type == "club" 
            @my_groups.push(grp)
          end
        end
      end
      member = GroupMember.where(student_id: student.id)
      member.each do |mb|
        grp = Group.find_by(id: mb.group_id, active: true)
        if grp != nil
          if grp.group_type == "club"
            @my_groups.push(grp)
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
            @my_groups.push(grp)
          end
        end
      end
    end
    puts "number of groups: " + @my_groups.length.to_s
    erb :my_clubs
  end
  
  get '/all_clubs' do
    verify_user
    @high_commitment = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "high commitment").id).order(name: :asc)
    @interest = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "interest").id).order(name: :asc)
    @affinity_groups = Group.where(group_type: "club", active: true, level_id: GroupLevel.find_by(name: "affinity group").id).order(name: :asc)
    erb :all_clubs
  end

  get '/my_sports' do
    verify_user
    student = Student.find_by(user_id: @active_user.id)
    @my_groups = []
    if student != nil
      leader = GroupLeader.where(student_id: student.id)
      leader.each do |ld|
        grp = Group.find_by(id: ld.group_id)
        if grp.group_type == "sport" 
          @my_groups.push(grp)
        end
      end
      member = GroupMember.where(student_id: student.id)
      member.each do |mb|
        grp = Group.find_by(id: mb.group_id)
        if grp.group_type == "sport"
          @my_groups.push(grp)
        end
      end 
    else
      fac = Facultystaff.find_by(user_id: @active_user.id)  
      group_adivsor = GroupAdvisor.where(facultystaff_id: fac.id)
      group_adivsor.each do |ga|
        grp = Group.find_by(id: ga.group_id)
        if grp.group_type == "sport" 
          @my_groups.push(grp)
        end
      end
    end
    erb :my_sports
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
    erb :all_sports
  end

  get '/add_group' do
    verify_user
    check_admin
    @group_types = []
    all_group_levels = GroupLevel.all
    all_group_levels.each do |level|
      @group_types.push(level)
    end

    @sports_seasons = Season.all
    
    #create hashes that have all of the necessary information for students by grade
    @sophomores = []
    @juniors = []
    @seniors = []
    all_students = Student.all
    all_users = User.all
    grades = Student.select(:class_of).distinct.sort()
    soph = grades[2].class_of
    jun = grades[1].class_of
    sen = grades[0].class_of
    all_students.each do |student|
      if student.class_of == soph
        @sophomores_hash = {:first => all_users.find_by(id: student.user_id).firstname, :last => all_users.find_by(id: student.user_id).lastname, :id => student.user_id}
        @sophomores.push(@sophomores_hash)
      end
      if student.class_of == jun
        @juniors_hash = {:first => all_users.find_by(id: student.user_id).firstname, :last => all_users.find_by(id: student.user_id).lastname, :id => student.user_id}
        @juniors.push(@juniors_hash)
      end
      if student.class_of == sen
        @seniors_hash = {:first => all_users.find_by(id: student.user_id).firstname, :last => all_users.find_by(id: student.user_id).lastname, :id => student.user_id}
        @seniors.push(@seniors_hash)
      end
    end
    
    
    erb :add_group
  end
  
  
  post "/create_group" do
    #create the group from form data and put into the schema
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
    redirect '/manage/manage_groups' #eventually redirect to the group you are adding members to
  end

  get '/all_clubs/:club_name/add_member' do
    verify_user
    club = params['club_name']
    underscore = "_"
    club.gsub!(underscore, " ")
    club.downcase!
    @current_group = Group.find_by(name: club)
    all_students = Student.all
    @freshmen = []
    @sophomores = []
    @juniors = []
    @seniors = []

    grades = Student.select(:class_of).distinct.sort()
    soph = grades[2].class_of
    jun = grades[1].class_of
    sen = grades[0].class_of

    all_students.each do |st|
      user = User.find_by(id: st.user_id)
      if st.class_of == sen
        @seniors.push(user)
      elsif st.class_of == jun
        @juniors.push(user)
      elsif st.class_of == soph
        @sophomores.push(user)
      else
        @freshmen.push(user)
      end
    end

    erb :add_to_clubs
    # redirect '/'
  end

  get '/all_sports/:sport/add_member' do
    verify_user
    sport = params[:sport]
    
    @current_group = Group.find_by(name: sport.gsub("_", " ").downcase)
    puts @current_group.name
    @student_list = User.where(id: Student.all.select(:user_id))
    erb :add_to_clubs
    # redirect '/'
  end

  post '/adding_members/:club_name' do
    club = params['club_name']
    underscore = "_"
    club.gsub!(underscore, " ")
    club.downcase!
    @current_group = Group.find_by(name: club)
    # puts "USERS: " + params[:user].to_s
    selected_users = params[:user]
    selected_users.each do |st|
      split_name = st.split(", ")
      user = User.find_by(firstname: split_name[1], lastname: split_name[0])
      # puts user.inspect
      # puts split_name[1]
      # puts split_name[0]
      student = Student.find_by(user_id: user.id)
      if GroupMember.find_by(student_id: student.id, group_id: @current_group.id) == nil
        if GroupLeader.find_by(student_id: student.id, group_id: @current_group.id) == nil
          GroupMember.create(student_id: student.id, group_id: @current_group.id)
        end
      end
    end
    if @current_group.group_type == "club"
      redirect '/all_clubs/'+params['club_name'].to_s
    elsif @current_group.group_type == "sport"
      redirect '/all_sports/'+ params['club_name'].to_s
    else
      puts @current_group.group_type + 'error'
      redirect '/error'
    end
  end

  get '/all_clubs/:club_name' do
    verify_user
    clubname = params[:club_name]
    # underscore = "_"
    club = clubname.gsub("_", " ").downcase
    puts clubname
    
    @current_group = Group.find_by(name: club)
    if @current_group.active and @current_group.group_type == "club"
      @club_members = []
      @club_leaders = []
      members = GroupMember.where(group_id: @current_group.id)
      leaders = GroupLeader.where(group_id: @current_group.id)
      members.each do |gm|
        student = Student.find_by(id: gm.student_id)
        user = User.find_by(id: student.user_id)
        @club_members << user
      end
      leaders.each do |gl|
        @club_leaders << Student.find_by(id: gl.student_id)
      end
      erb :club_page
    else
      erb :error
    end
  end

  get '/all_sports/:sport_name' do
    verify_user
    sport = params['sport_name']
    sport.gsub!('_', " ")
    @current_group = Group.find_by(name: sport)
    if @current_group.active and @current_group.group_type == "sport"
      @record = Game.where(team_id: @current_group.id).order(date: :desc)
      unordered_roster = GroupMember.where(group_id: @current_group.id).select(:student_id)
      # puts Student.where(GroupMember.where(group_id: @current_group.id).select(:student_id)
      @roster = User.where(id: (Student.where(id: GroupMember.where(group_id: @current_group.id).select(:student_id)).select(:user_id))).order(firstname: :asc)
      @coaches = User.where(id: (Facultystaff.where(id: GroupAdvisor.where(group_id: @current_group.id).select(:facultystaff_id)).select(:user_id))).order(firstname: :asc)
      @leader = @active_user.is_admin or GroupLeader.find_by(group_id: @current_group.id, student_id: Student.find_by(user_id: active_user.id).id).exist? or GroupAdvisor.find_by(group_id: @current_group.id, facultystaff_id: Facultystaff.find_by(user_id: active_user.id).id).exist?
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
      erb :sports_page
    else
      erb :error
    end
  end

  get '/all_clubs/:name/add_meeting' do
    verify_user
    name = params[:name].gsub("_", " ")
    @current_group = Group.find_by(name: name)
    if GroupLeader.find_by(group_id: @current_group.id, student_id: @active_user.id) != nil
      erb :add_club_meeting
    else
      erb :error
    end
  end

  post '/push_club_meeting' do
    #still need to build frontend 
    location = params[:location]
    date = params[:date]
    id = params[:id].to_i #need to specifically pass as ID
    desc = params[:description]
    meeting = GroupMeeting.create(location: location, event_date: date, group_id: id.to_i, description: desc)
    redirect "/meetings"
  end

  get '/all_sports/:name/add_game' do
    verify_user
    name = params[:name].gsub("_", " ")
    @current_group = Group.find_by(name: name)
    erb :add_game
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
    #need to add check admin functionality
    @game = Game.find_by(id: params[:id].to_i)
    erb :edit_game
  end

  post '/edit_game' do
    game = Game.find_by(id: params[:id].to_i)
    if params[:cancel] == 'on'
      status = false
    else
      status = true
    end
    name = params[:name]
    id = params[:id]
    date = params[:date].to_datetime
    home = params[:advantage]
    h_score = params[:hscore]
    a_score = params[:ascore]
    details = params[:details]
    result = params[:result]
    id = params[:id].to_i 
    game.update(status: status, name: name, date: date, advantage: home, 
    home_score: h_score, away_score: a_score, details: details, result: result)
    sport = Group.find(game.team_id)
    redirect "/all_sports/"+ sport.name.gsub(" ", "_").to_s
  end

  post '/delete_game' do
    game = Game.find_by(id: params[:id])
    sport = Group.find(game.team_id)
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
      erb :add_sport_image
    else
      erb :error
    end
  end

  post '/upload_sport_image' do
    id = params[:id]
    sport = Group.find(id)
    sport_name = sport.name.gsub(" ", "_")
    puts File.dirname(__FILE__)

    photo = params[:imageUpload][:tempfile].read
    # path = Pathname.new('../public/' + sport_name + ".txt")
    path = File.dirname(__FILE__) + '/public/sports/'+sport_name + '.jpg'
    File.open(path, 'wb') do |f|
      f.write(photo)
    end
    # if params[:imageFile]
    #   filename = params[:imageFile][:filename] 
    #   puts filename
    #   file = params[:imageFile][:tempfile]
    #   puts "foundfile"
    #   File.open(File.join("./public/clubs", params[:club_name].to_s + File.extname(filename)), 'wb') do |f|
    #   #File.open(File.join("/public/clubs/", filename), 'wb') do |f|
    #     f.write (file.read)
    #   end
    # end
    # photo.write_to_file '/public/' + sport_name + ".jpg"
    redirect '/all_sports/' + sport_name
  end

  get '/all_clubs/:club_name/editclub' do
    verify_user
    groupname=params["club_name"].downcase.gsub("_"," ")
    @updatepath="/my_clubs/"+params[:club_name].to_s+"/update_club"
    @imagepath=params["club_name"]+".jpg"
    @groupedit=Group.find_by(name: groupname)
    erb :edit_clubs
  end

  post '/all_clubs/:club_name/update_club' do 
    if params[:imageFile]
      filename = params[:imageFile][:filename] 
      puts filename
      file = params[:imageFile][:tempfile]
      puts "foundfile"
      File.open(File.join("./public/clubs", params[:club_name].to_s + File.extname(filename)), 'wb') do |f|
      #File.open(File.join("/public/clubs/", filename), 'wb') do |f|
        f.write (file.read)
      end
    end
    groupname=params["club_name"].downcase.gsub("_"," ")
    @groupedit=Group.find_by(name: groupname)
    @groupedit.update(description: params["description"].strip) 
    redirect "/my_clubs/" + params[:club_name] + "/editclub"
  end 

  get '/meetings' do 
    verify_user

    @groups = Group.all
    all_meetings = GroupMeeting.all
    my_group_list = GroupLeader.where(student_id: @active_user.id) + GroupMember.where(student_id: @active_user.id)
    @my_groups = []
    @meetings = []

    all_meetings.each do |meeting|
      if  meeting.event_date > Time.now()
        @meetings.push(meeting)
      end
    end

    my_group_list.each do |group|
      @my_groups.push(@groups.find_by(id: group.group_id).id)
    end

    @meetings = @meetings.sort_by {|meeting| meeting.event_date}

    erb :meetings
  end

  get '/meetings/edit' do
    verify_user
    @meeting = GroupMeeting.find_by(id: params[:id])
    if GroupLeader.find_by(group_id: @meeting.group_id, student_id: @active_user.id) != nil
      erb :edit_meeting
    else
      erb :error
    end
  end

  post '/update_meeting' do
    meeting = GroupMeeting.find_by(id: params[:id])
    location = params[:location]
    date = params[:date].to_datetime #calendar on the frontend
    desc = params[:desc]
    meeting.update(location: location, event_date: date, description: desc) # this one - should be an edit 
    redirect '/meetings'
  end
  post '/delete_meeting' do
    meeting = GroupMeeting.find_by(id: params[:id])
    meeting.delete
    redirect '/meetings'
  end
  ##########################################
end


