#Teams
white = BwTeam.create(team_color: 'white')
blue = BwTeam.create(team_color: 'blue')

#Users - Just a few for testing purposes
user1 = User.create(firstname: "Jane", lastname:"Rollenhagen", email:"janey.rollenhagen.2025@holton-arms.edu", team_id: blue.id)
student1 = Student.create(grade: 12, user_id: user1.id)

user2 = User.create(firstname: "Grace", lastname:"Ding", email:"grace.ding.2025@holton-arms.edu", team_id: blue.id)
student2 = Student.create(grade: 12, user_id: user2.id)

user3 = User.create(firstname: "Kriti", lastname:"Hota", email:"kriti.hota.2026@holton-arms.edu", team_id: blue.id)
student3 = Student.create(grade: 11, user_id: user3.id)

user4 = User.create(firstname: "Katherine", lastname:"Snider", email:"katherine.snider.2027@holton-arms.edu", team_id: white.id)
student4 = Student.create(grade: 10, user_id: user4.id)

user5 = User.create(firstname: "Heidi", lastname:"Trambley", email:"heidi.trambley.2025@holton-arms.edu", team_id: white.id)
student5 = Student.create(grade: 12, user_id: user5.id)

user6 = User.create(firstname: "Lindsay", lastname:"Kossoff", email:"lindsay.kossoff.2025@holton-arms.edu", team_id: blue.id)
student6 = Student.create(grade: 12, user_id: user6.id)

user7 = User.create(firstname: "Joseph", lastname:"Rivera", email:"joseph.rivera@holton-arms.edu", team_id: white.id, is_admin: true)
#facstaff1 = FacultyStaff.create(grade: 12, user_id: user7.id)

user8 = User.create(firstname: "Tucker", lastname:"Sowers", email:"tucker.sowers@holton-arms.edu", team_id: white.id)
#facstaff2 = FacultyStaff.create(grade: 9, user_id: user8.id)

# #Seasons
fall = Season.create(name: "Fall", start_date: DateTime.new(2024, 8, 22))
winter  = Season.create(name: "Winter", start_date: DateTime.new(2024, 11, 14))
spring = Season.create(name: "Spring", start_date: DateTime.new(2024, 3, 24))


# #divisions
upper = Division.create(name: "Upper School")
lower = Division.create(name: "Lower School")
middle = Division.create(name: "Middle School")
all = Division.create(name: "All School")

#group levels

GroupLevel.create(name: "high commitment", description: "many meetings, attendance required, events", limit: 2)
GroupLevel.create(name: "interest", description: "casual, activity and fun-oriented", limit: 3)
GroupLevel.create(name: "varsity", description: "varsity sport", limit: -1)
GroupLevel.create(name: "junior varsity", description: "jv sport", limit: -1)
GroupLevel.create(name: "affinity group", description: "activities and learning oriented around shared identities.", limit: -1)

