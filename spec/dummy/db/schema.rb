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

ActiveRecord::Schema.define(version: 2019_08_15_192130) do

  create_table "lab_tech_experiments", force: :cascade do |t|
    t.string "name"
    t.integer "percent_enabled", default: 0, null: false
    t.integer "equivalent_count", default: 0, null: false
    t.integer "timed_out_count", default: 0, null: false
    t.integer "other_error_count", default: 0, null: false
    t.index ["name"], name: "index_lab_tech_experiments_by_name", unique: true
  end

  create_table "lab_tech_observations", force: :cascade do |t|
    t.integer "result_id", null: false
    t.string "name", limit: 100
    t.float "duration", limit: 24
    t.text "value", limit: 4294967295
    t.text "sql"
    t.string "exception_class"
    t.text "exception_message"
    t.text "exception_backtrace"
    t.datetime "created_at"
    t.index ["result_id"], name: "index_lab_tech_observations_by_result_id"
  end

  create_table "lab_tech_results", force: :cascade do |t|
    t.integer "experiment_id", null: false
    t.text "context"
    t.boolean "equivalent", default: false, null: false
    t.boolean "raised_error", default: false, null: false
    t.float "time_delta", limit: 24
    t.float "speedup_factor", limit: 24
    t.datetime "created_at"
    t.boolean "timed_out", default: false, null: false
    t.float "control_duration", limit: 24
    t.float "candidate_duration", limit: 24
    t.index ["experiment_id", "equivalent"], name: "index_lab_tech_results_by_exp_id_and_equivalent"
    t.index ["experiment_id", "raised_error"], name: "index_lab_tech_results_by_exp_id_and_raised"
  end

end
