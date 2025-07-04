#Teams
white = BwTeam.create(team_color: 'white')
blue = BwTeam.create(team_color: 'blue')

#Users - Just a few for testing purposes
user1 = User.create(firstname: "Jane", lastname:"Rollenhagen", email:"janey.rollenhagen.2025@holton-arms.edu", team_id: blue.id, is_admin: true)
student1 = Student.create(class_of: 2025, user_id: user1.id)
user2 = User.create(firstname: "Grace", lastname:"Ding", email:"grace.ding.2025@holton-arms.edu", team_id: blue.id, is_admin: true)
student2 = Student.create(class_of: 2025, user_id: user2.id)
user3 = User.create(firstname: "Kriti", lastname:"Hota", email:"kriti.hota.2026@holton-arms.edu", team_id: blue.id, is_admin: true)
student3 = Student.create(class_of: 2026, user_id: user3.id)
user4 = User.create(firstname: "Katherine", lastname:"Snider", email:"katherine.snider.2027@holton-arms.edu", team_id: white.id, is_admin: true)
student4 = Student.create(class_of: 2027, user_id: user4.id)
user5 = User.create(firstname: "Heidi", lastname:"Trambley", email:"heidi.trambley.2025@holton-arms.edu", team_id: white.id, is_admin: true)
student5 = Student.create(class_of: 2025, user_id: user5.id)
user6 = User.create(firstname: "Lindsay", lastname:"Kossoff", email:"lindsay.kossoff.2025@holton-arms.edu", team_id: blue.id, is_admin: true)
student6 = Student.create(class_of: 2025, user_id: user6.id)
user7 = User.create(firstname: "Joseph", lastname:"Rivera", email:"joseph.rivera@holton-arms.edu", team_id: white.id, is_admin: true)
facstaff1 = Facultystaff.create(grade: 12, user_id: user7.id)
user8 = User.create(firstname: "Tucker", lastname:"Sowers", email:"tucker.sowers@holton-arms.edu", team_id: white.id, is_admin: true)
facstaff2 = Facultystaff.create(grade: 9, user_id: user8.id)
user9 = User.create(firstname: "Kate", lastname:"Mitchell", email:"kate.mitchell@holton-arms.edu", team_id: white.id, is_admin: true)
facstaff3 = Facultystaff.create(grade: 12, user_id: user9.id)

#Seasons
fall = Season.create(name: "Fall", start_date: DateTime.new(2024, 8, 22))
winter  = Season.create(name: "Winter", start_date: DateTime.new(2024, 11, 14))
spring = Season.create(name: "Spring", start_date: DateTime.new(2024, 3, 24))


# #divisions
upper = Division.create(name: "Upper School")
lower = Division.create(name: "Lower School")
middle = Division.create(name: "Middle School")
all = Division.create(name: "All School")

#group levels

high = GroupLevel.create(name: "high commitment", description: "many meetings, attendance required, events", limit: 2)
interest = GroupLevel.create(name: "interest", description: "casual, activity and fun-oriented", limit: 3)
varsity = GroupLevel.create(name: "varsity", description: "varsity sport", limit: -1)
GroupLevel.create(name: "junior varsity", description: "jv sport", limit: -1)
GroupLevel.create(name: "affinity group", description: "activities and learning oriented around shared identities.", limit: -1)
GroupLevel.create(name: "club sport", description: "club sport", limit: -1)

#groups
debate = Group.create(name: "debate team", description: "Group dedicated to competitive debate events and activities", group_type: "club", level_id: high.id)
soccer = Group.create(name: "varsity soccer", description: "Team dedicated to playing futbol.", group_type: "sport", level_id: varsity.id)
cheese = Group.create(name: "cheese club", description: "All things cheese related!", group_type: "club", level_id: interest.id)
softball = Group.create(name: "softball", description: "Baseball with an bigger ball.", group_type: "sport", level_id: varsity.id)

#sports results
softball_game = Game.create(name: "vs. Holy Child", team_id: softball.id, date: DateTime.new(2001,2,3, 1), advantage: true, result: "win")
softball_game = Game.create(name: "vs. Holy Child", team_id: softball.id, date: DateTime.new(2002,3,5, 2), advantage: true, result: "win")

#group leaders/members
GroupLeader.create(group_id: cheese.id, student_id: student5.id)
GroupLeader.create(group_id: debate.id, student_id: student2.id)
GroupMember.create(group_id: soccer.id, student_id: student5.id)
GroupMember.create(group_id: softball.id, student_id: student5.id)
GroupLeader.create(group_id: cheese.id, student_id: student1.id)
GroupMember.create(group_id: soccer.id, student_id: student1.id)
GroupMember.create(group_id: debate.id, student_id: student1.id)

GroupAdvisor.create(group_id: cheese.id, facultystaff_id: facstaff1.id)

#group seasons
GroupSeason.create(group_id: soccer.id, season_id: fall.id)
GroupSeason.create(group_id: softball.id, season_id: spring.id)

#message tags
MessageTag.create(recipient_tag: "Upper School")
MessageTag.create(recipient_tag: "Class of 2025")
MessageTag.create(recipient_tag: "Class of 2026")
MessageTag.create(recipient_tag: "Class of 2027")
MessageTag.create(recipient_tag: "Class of 2028")
debate_tag = MessageTag.create(recipient_tag: "Debate Team")
soccer_tag = MessageTag.create(recipient_tag: "Varsity Soccer")
cheese_tag = MessageTag.create(recipient_tag: "Cheese Club")
soft_tag = MessageTag.create(recipient_tag: "Softball") 


#group message tags
GroupMessagetag.create(group_id: debate.id, messagetag_id: debate_tag.id)
GroupMessagetag.create(group_id: soccer.id, messagetag_id: soccer_tag.id)
GroupMessagetag.create(group_id: cheese.id, messagetag_id: cheese_tag.id)
GroupMessagetag.create(group_id: softball.id, messagetag_id: soft_tag.id)


#Group leaders
GroupLeader.create(group_id: debate.id, student_id: 6)

#group members
GroupMember.create(student_id: 6, group_id: cheese.id)
GroupMember.create(student_id: 6, group_id: softball.id)

#group meetings
GroupMeeting.create(location: "gym", event_date: DateTime.new(2025, 3, 12, 3, 30), group_id: softball.id)
GroupMeeting.create(location: "field", event_date: DateTime.new(2025, 3, 20, 5, 00), group_id: softball.id)


GroupMeeting.create(location: "cafeteria", event_date: DateTime.new(2025, 4, 30, 1, 00), group_id: cheese.id)
GroupMeeting.create(location: "room 123", event_date: DateTime.new(2025, 2, 28, 10, 55), group_id: cheese.id)
GroupMeeting.create(location: "cafe", event_date: DateTime.new(2025, 5, 1, 2, 45), group_id: cheese.id)

GroupMeeting.create(location: "room 208", event_date: DateTime.new(2025, 4, 1, 10, 55), group_id: debate.id)
GroupMeeting.create(location: "room 208", event_date: DateTime.new(2025, 1, 20, 3, 30), group_id: debate.id)
GroupMeeting.create(location: "room 208", event_date: DateTime.new(2025, 3, 15, 1, 00), group_id: debate.id)
GroupMeeting.create(location: "room 208", event_date: DateTime.new(2025, 1, 15, 2, 45), group_id: debate.id)

GroupMeeting.create(location: "field", event_date: DateTime.new(2025, 3, 15, 1, 00), group_id: soccer.id)
GroupMeeting.create(location: "field", event_date: DateTime.new(2025, 3, 20, 2, 45), group_id: soccer.id)

Game.create(name:"soccermatch", team_id: soccer.id, date: DateTime.new(2025, 3, 14, 4, 15), advantage: true, home_score: 2, away_score: 0, result: "win")
Game.create(name:"soccermatch2", team_id: soccer.id, date: DateTime.new(2025, 4, 17, 4, 15), details: "Opponent", status: true, advantage: false)
Game.create(name:"soccermatch3", team_id: soccer.id, date: DateTime.new(2025, 4, 15, 4, 15), details: "Opponent", status: false, advantage: true)
Game.create(name:"softballgame", team_id: softball.id, date: DateTime.new(2025, 5, 5, 4, 15), details: "Opponent", status: true,  advantage: true)

#schedule blocks
Assembly = ScheduleBlock.create(description: "Assembly", start: DateTime.new(2025, 1, 1, 8, 0), duration: 15.0)
U1 = ScheduleBlock.create(description: "U1", start: DateTime.new(2025, 1, 1, 8, 15), duration: 50.0)
U3 = ScheduleBlock.create(description: "U3", start: DateTime.new(2025, 1, 1, 9, 10), duration: 50.0)
U5 = ScheduleBlock.create(description: "U5", start: DateTime.new(2025, 1, 1, 10, 5), duration: 50.0)
Break = ScheduleBlock.create(description: "Break", start: DateTime.new(2025, 1, 1, 10, 55), duration: 20.0)  
U6 = ScheduleBlock.create(description: "U6", start: DateTime.new(2025, 1, 1, 11, 15), duration: 50.0) 
U7 = ScheduleBlock.create(description: "U7", start: DateTime.new(2025, 1, 1, 12, 5), duration: 50.0) 
Lunch = ScheduleBlock.create(description: "Lunch", start: DateTime.new(2025, 1, 1, 1, 0), duration: 50.0) 
U8 = ScheduleBlock.create(description: "U8", start: DateTime.new(2025, 1, 1, 1, 50), duration: 50.0) 
U9 = ScheduleBlock.create(description: "U9", start: DateTime.new(2025, 1, 1, 2, 45), duration: 45.0) 

blue_monday = DailySchedule.create(week_type: "blue", day: 1, day_of_the_week: "monday", date_of: DateTime.new(2025, 4, 7))
blue_tuesday = DailySchedule.create(week_type: "blue", day: 2, day_of_the_week: "tuesday", date_of: DateTime.new(2025, 4, 8))
blue_wednesday = DailySchedule.create(week_type: "blue", day: 3, day_of_the_week: "wednesday", date_of: DateTime.new(2025, 4, 9))
blue_thursday = DailySchedule.create(week_type: "blue", day: 4, day_of_the_week: "thursday", date_of: DateTime.new(2025, 4, 10))
blue_friday = DailySchedule.create(week_type: "blue", day: 5, day_of_the_week: "friday", date_of: DateTime.new(2025, 4, 11))
white_monday = DailySchedule.create(week_type: "white", day: 6, day_of_the_week: "monday", date_of: DateTime.new(2025, 4, 14))
white_tuesday = DailySchedule.create(week_type: "white", day: 7, day_of_the_week: "tuesday", date_of: DateTime.new(2025, 4, 15))
white_wednesday = DailySchedule.create(week_type: "white", day: 8, day_of_the_week: "wednesday", date_of: DateTime.new(2025, 4, 16))
white_thursday = DailySchedule.create(week_type: "white", day: 9, day_of_the_week: "thursday", date_of: DateTime.new(2025, 4, 17))
white_friday = DailySchedule.create(week_type: "white", day: 10, day_of_the_week: "friday", date_of: DateTime.new(2025, 4, 18))


DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: Assembly.id) 
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: U1.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: U3.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: U5.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: Break.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: U6.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: U7.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: Lunch.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: U8.id)
DailyScheduleScheduleBlock.create(dailyschedule_id: blue_monday.id, block_id: U9.id)
