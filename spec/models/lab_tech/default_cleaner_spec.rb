require 'rails_helper'

RSpec.describe LabTech::DefaultCleaner, type: :model do
  subject(:cleaner) { LabTech::DefaultCleaner }

  def clean(value)
    cleaner.call(value)
  end

  it "returns an integer as itself" do
    expect( clean(42) ).to eq( 42 )
  end

  it "returns an AR instance as a pair of [ class_name, id ]" do
    exp = LabTech::Experiment.create(name: "whatever")
    expect( clean(exp) ).to eq( [ "LabTech::Experiment", exp.id ] )
  end

  it "returns an array of integers as itself" do
    expect( clean( [1,2,3] ) ).to eq( [1,2,3] )
  end

  it "returns an array of AR instances as a hash containing a list of IDs keyed by class name" do
    e1, e2 = 2.times.map {|i| LabTech::Experiment.create(name: "Experiment #{i}") }
    expect( clean( [e1, e2] ) ).to eq(
      {
        "LabTech::Experiment" => [ e1.id, e2.id ],
      }
    )
  end
end

