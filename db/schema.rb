# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20130926092312) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "games", force: true do |t|
    t.integer  "black_player_id"
    t.integer  "white_player_id"
    t.integer  "creator_id",                null: false
    t.string   "description"
    t.integer  "board_size",      limit: 2
    t.integer  "handicap",        limit: 2
    t.integer  "komi",            limit: 2
    t.string   "rule_set"
    t.string   "time_settings"
    t.integer  "status",          limit: 2
    t.integer  "type",            limit: 2
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "games", ["black_player_id"], name: "index_games_on_black_player_id", using: :btree
  add_index "games", ["white_player_id"], name: "index_games_on_white_player_id", using: :btree

  create_table "users", force: true do |t|
    t.string   "username",                   null: false
    t.string   "password_digest"
    t.string   "email"
    t.integer  "status",           limit: 2
    t.string   "rank"
    t.text     "account_settings"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", using: :btree
  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree

end
