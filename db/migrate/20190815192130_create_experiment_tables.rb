class CreateExperimentTables < ActiveRecord::Migration[5.1]
  def change

    #  Quick E-R diagram:
    #
    #  +------------+     +--------+     +-------------+
    #  | Experiment |----E| Result |----E| Observation |
    #  +------------+     +--------+     +-------------+

    create_table "lab_tech_experiments" do |t|
      t.string    "name"
      t.integer   "percent_enabled",   null: false, default: 0
      t.integer   "equivalent_count",  null: false, default: 0
      t.integer   "timed_out_count",   null: false, default: 0
      t.integer   "other_error_count", null: false, default: 0

      t.index [ "name" ], unique: true, name: "index_lab_tech_experiments_by_name"
    end

    create_table "lab_tech_results" do |t|
      t.integer  "experiment_id",      null: false
      t.text     "context"
      t.boolean  "equivalent",         null: false, default: false
      t.boolean  "raised_error",       null: false, default: false
      t.float    "time_delta",         limit: 24
      t.float    "speedup_factor",     limit: 24
      t.datetime "created_at"
      t.boolean  "timed_out",          null: false, default: false
      t.float    "control_duration",   limit: 24
      t.float    "candidate_duration", limit: 24

      t.index [ "experiment_id", "equivalent" ],   name: "index_lab_tech_results_by_exp_id_and_equivalent"
      t.index [ "experiment_id", "raised_error" ], name: "index_lab_tech_results_by_exp_id_and_raised"
    end

    create_table "lab_tech_observations" do |t|
      t.integer  "result_id", null: false
      t.string   "name",      limit: 100
      t.float    "duration",  limit: 24
      t.text     "value",     limit: 4294967295
      t.text     "sql"
      t.string   "exception_class"
      t.text     "exception_message"
      t.text     "exception_backtrace"
      t.datetime "created_at"

      t.index [ "result_id" ], name: "index_lab_tech_observations_by_result_id"
    end
  end
end
