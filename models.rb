class User < ActiveRecord::Base
end

class Student < ActiveRecord::Base
    has_one :user
end

class Facultystaff < ActiveRecord::Base
    has_one :user
end

class BwTeam < ActiveRecord::Base
end

class Division < ActiveRecord::Base
end

class Message < ActiveRecord::Base
    has_and_belongs_to_many :message_tags
    has_many :groups, through: :message_tags
end

class BwEventDivision < ActiveRecord::Base
end

class BwEvent < ActiveRecord::Base
end

class MessageTag < ActiveRecord::Base
    has_one :group
end

class MessageMessageTag < ActiveRecord::Base
end

class Game < ActiveRecord::Base
end

class Group < ActiveRecord::Base
end

class GroupAdvisor < ActiveRecord::Base
end

class GroupLeader < ActiveRecord::Base
end

class GroupMember < ActiveRecord::Base
end

class GroupSeason < ActiveRecord::Base
end

class Season < ActiveRecord::Base
end

class GroupMeeting < ActiveRecord::Base
end

class GroupLevel < ActiveRecord::Base
end

class GroupMessagetag < ActiveRecord::Base
end
