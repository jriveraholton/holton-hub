# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_01_16_151215) do
  create_table "bw_event_divisions", force: :cascade do |t|
    t.integer "bw_event_id", null: false
    t.integer "division_id", null: false
  end

  create_table "bw_events", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "event_date", null: false
    t.integer "blue_points"
    t.integer "white_points"
    t.integer "division_id", null: false
  end

  create_table "bw_teams", force: :cascade do |t|
    t.string "team_color", null: false
    t.integer "captain_id"
    t.integer "win_count", default: 0, null: false
  end

  create_table "divisions", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "facultystaffs", force: :cascade do |t|
    t.integer "grade"
    t.integer "user_id"
  end

  create_table "group_advisors", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "facultystaff_id", null: false
  end

  create_table "group_leaders", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "student_id", null: false
  end

  create_table "group_levels", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.integer "limit", null: false
  end

  create_table "group_meetings", force: :cascade do |t|
    t.string "location", null: false
    t.datetime "event_date", null: false
    t.integer "group_id", null: false
  end

  create_table "group_members", force: :cascade do |t|
    t.integer "student_id", null: false
    t.integer "group_id", null: false
  end

  create_table "group_messagetags", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "messagetag_id", null: false
  end

  create_table "group_seasons", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "season_id", null: false
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.string "group_type", null: false
    t.integer "level_id", null: false
  end

  create_table "message_message_tags", force: :cascade do |t|
    t.integer "message_id", null: false
    t.integer "message_tag_id", null: false
  end

  create_table "message_tags", force: :cascade do |t|
    t.string "recipient_tag"
  end

  create_table "messages", force: :cascade do |t|
    t.string "subject", null: false
    t.text "content", null: false
    t.datetime "sent_at", null: false
    t.integer "author_id", null: false
  end

  create_table "seasons", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "start_date", null: false
  end

  create_table "students", force: :cascade do |t|
    t.integer "grade", null: false
    t.integer "user_id", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "firstname", null: false
    t.string "lastname", null: false
    t.string "email", null: false
    t.string "secret"
    t.integer "team_id"
    t.boolean "is_admin", default: false, null: false
    t.boolean "active", default: true, null: false
  end
end
