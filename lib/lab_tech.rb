require "lab_tech/engine"
require "scientist"

module LabTech
  extend self

  ########################################################################
  #
  #   So, you've come here for science?  EXCELLENT.
  #
  #   TL;DR:
  #
  #   LabTech.science "experiment-name" do |exp|
  #     exp.use { STABLE_CODE } # this is the "control"
  #     exp.try { BETTER_CODE } # this is the "candidate"
  #
  #     # Optional, but often useful:
  #     exp.context foo: "spam", bar: "eggs", yak: "bacon"
  #     exp.compare {|control, candidate| control.map(&:id) == candidate.map(&:id) }
  #     exp.clean { |records| records.map(&:id) }
  #   end
  #
  #   See https://github.com/github/scientist for an *extremely* detailed
  #   README that explains how to use this.  For those purposes, the thing
  #   passed to the block as `exp` is a Scientist::Experiment.
  #
  #   NOTE: You'll probably want to check out the .enable and .disable methods
  #   below if you want your candidate code to actually *run*...
  #
  ########################################################################
  def science(experiment_name, opts = {}, &block)
    experiment = Experiment.named( experiment_name )

    yield experiment

    test = opts[:run] if opts # TODO: figure out what this line was supposed to be for ¯\_(ツ)_/¯
    experiment.run(test)
  end

  ########################################################################
  #
  #   This here is how you turn individual experiments on and off
  #
  ########################################################################
  def self.enable(*experiment_names, percent: 100)
    experiments_named( experiment_names ) do |exp|
      exp.enable percent_enabled: percent
    end
  end

  def self.disable(*experiment_names)
    experiments_named( experiment_names, &:disable )
  end

  ########################################################################
  #
  #   You'll probably want to see how your experiments are doing...
  #
  ########################################################################
  def self.summarize_results(*experiment_names)
    experiments_named( experiment_names, &:summarize_results )
  end

  ########################################################################
  #
  #   ...and be annoyed when they're not 100% correct...
  #
  ########################################################################
  #
  #   By default, this will simply print the values of all mismatches.
  #   However, if you'd like to pass a block that returns arguments to
  #   IO#puts, you can probably get more useful results.
  #
  #   Here's one example based on an experiment that records the IDs
  #   returned from a search:
  #
  #     comparison = ->(cont, cand) {
  #       cont_ids, cand_ids = cont.value, cand.value
  #       case
  #       when cont_ids      == cand_ids      ; "EVERYTHING IS FINE" # if this were true, it wouldn't be a mismatch
  #       when cont_ids.sort == cand_ids.sort ; "ORDER DIFFERS"
  #       else
  #         [
  #           "CONTROL   length: #{ cont_ids.length }",
  #           "CANDIDATE length: #{ cand_ids.length }",
  #           "    missing: #{ (cont_ids - cand_ids).inspect }",
  #           "    extra:   #{ (cand_ids - cont_ids).inspect }",
  #         ]
  #       end
  #     }
  #     e = Experiment.named "isolate-lead-activities-in-lead-search"
  #     e.compare_mismatches limit: 10, &comparison
  #
  #   And here's another one that assumes you've recorded a hash of the form:
  #   { ids: [ 1, 2, ... ], sql: "SELECT FROM ..." }
  #
  #     comparison = ->(cont, cand) {
  #       cont_ids, cand_ids = cont.value.fetch(:ids), cand.value.fetch(:ids)
  #       cont_sql, cand_sql = cont.value.fetch(:sql), cand.value.fetch(:sql)
  #       sql_strings = [ "", "CONTROL SQL", cont_sql, "", "CANDIDATE SQL", cand_sql ]
  #       case
  #       when cont_ids      == cand_ids      ; "EVERYTHING IS FINE" # if this were true, it wouldn't be a mismatch
  #       when cont_ids.sort == cand_ids.sort ; [ "ORDER DIFFERS" ] + sql_strings
  #       else
  #         [
  #           "CONTROL   length: #{ cont_ids.length }",
  #           "CANDIDATE length: #{ cand_ids.length }",
  #           "    missing: #{ (cont_ids - cand_ids).inspect }",
  #           "    extra:   #{ (cand_ids - cont_ids).inspect }",
  #         ] + sql_strings
  #       end
  #     }
  #     e = Experiment.named "isolate-lead-activities-in-lead-search"
  #     e.compare_mismatches limit: 10, &comparison
  #
  ########################################################################
  def self.compare_mismatches(experiment_name, limit: nil, io: $stdout, &block)
    exp = LabTech::Experiment.named( experiment_name )
    exp.compare_mismatches limit: limit, io: io, &block
  end

  ########################################################################
  #
  #   ...and be curious about the errors...
  #
  ########################################################################
  def self.summarize_errors(experiment_name, limit: nil, io: $stdout)
    exp = LabTech::Experiment.named( experiment_name, limit: limit, io: io )
    exp.summarize_errors
  end


  ########################################################################
  #
  #   Sometimes we want to act on a batch of experiments
  #   (this is mostly just plumbing; feel free to ignore it)
  #
  ########################################################################
  def self.experiments_named(*experiment_names, &block)
    names = experiment_names.flatten.compact
    names.each do |exp_name|
      LabTech::Experiment.named(exp_name, &block)
    end
  end

end
