require 'rails_helper'

RSpec.describe LabTech::Speedup do
  # Some quick reference calculations.
  #
  # baseline | comparison | time | factor | comment
  # 2.0      | 1.0        | +1.0 | +2.0   |
  # 2.0      | 1.5        | +0.5 | +1.333 |
  # 2.0      | 2.0        |  0.0 | +0.0   | zero by definition
  # 2.0      | 2.5        | -0.5 | -1.25  |
  # 2.0      | 3.0        | -1.0 | -1.5   |
  # 2.0      | 3.5        | -1.5 | -1.75  |
  # 2.0      | 4.0        | -2.0 | -2.0   |

  specify ".compute_time_delta" do
    aggregate_failures do
      expect( described_class.compute_time_delta( 2.0, 1.0 ) ).to be_within( 0.001 ).of( +1.0 )
      expect( described_class.compute_time_delta( 2.0, 1.5 ) ).to be_within( 0.001 ).of( +0.5 )
      expect( described_class.compute_time_delta( 2.0, 2.0 ) ).to be_within( 0.001 ).of(  0.0 )
      expect( described_class.compute_time_delta( 2.0, 2.5 ) ).to be_within( 0.001 ).of( -0.5 )
      expect( described_class.compute_time_delta( 2.0, 3.0 ) ).to be_within( 0.001 ).of( -1.0 )
      expect( described_class.compute_time_delta( 2.0, 3.5 ) ).to be_within( 0.001 ).of( -1.5 )
      expect( described_class.compute_time_delta( 2.0, 4.0 ) ).to be_within( 0.001 ).of( -2.0 )
    end
  end

  specify ".compute_factor" do
    aggregate_failures do
      expect( described_class.compute_factor( 2.0, 1.0 ) ).to be_within( 0.001 ).of( +2.0   )
      expect( described_class.compute_factor( 2.0, 1.5 ) ).to be_within( 0.001 ).of( +1.333 )
      expect( described_class.compute_factor( 2.0, 2.0 ) ).to be_within( 0.001 ).of(  0.0   )
      expect( described_class.compute_factor( 2.0, 2.5 ) ).to be_within( 0.001 ).of( -1.25  )
      expect( described_class.compute_factor( 2.0, 3.0 ) ).to be_within( 0.001 ).of( -1.5   )
      expect( described_class.compute_factor( 2.0, 3.5 ) ).to be_within( 0.001 ).of( -1.75  )
      expect( described_class.compute_factor( 2.0, 4.0 ) ).to be_within( 0.001 ).of( -2.0   )
    end
  end

  def new_speedup(baseline = nil, comparison = nil, time = nil, factor = nil)
    described_class.new( baseline: baseline, comparison: comparison, time: time, factor: factor )
  end

  it "acts like a simple model when all attributes are provided" do
    x = new_speedup( 2.0, 1.0, -1.0, 2.0 )

    expect( x.baseline   ).to eq( +2.0 )
    expect( x.comparison ).to eq( +1.0 )
    expect( x.time       ).to eq( -1.0 )
    expect( x.factor     ).to eq( +2.0 )
  end

  it "cheerfully tolerates missing baseline and comparison" do
    x = new_speedup( nil, nil, -1.0, 2.0 )

    expect( x.baseline   ).to be nil
    expect( x.comparison ).to be nil
    expect( x.time       ).to eq( -1.0 )
    expect( x.factor     ).to eq( +2.0 )
  end

  it "computes time and factor if they're missing (and it has enough data to do so)" do
    x = new_speedup( 2.0, 1.0, nil, nil )

    expect( x.baseline   ).to eq( +2.0 )
    expect( x.comparison ).to eq( +1.0 )
    expect( x.time       ).to eq( +1.0 )
    expect( x.factor     ).to eq( +2.0 )
  end

  it "doesn't compute time and factor if baseline is missing" do
    x = new_speedup( 2.0, nil, nil, nil )

    expect( x.baseline   ).to eq( +2.0 )
    expect( x.comparison ).to be nil
    expect( x.time       ).to be nil
    expect( x.factor     ).to be nil
  end

  it "doesn't compute time and factor if comparison is missing" do
    x = new_speedup( nil, 2.0, nil, nil )

    expect( x.baseline   ).to be nil
    expect( x.comparison ).to eq( +2.0 )
    expect( x.time       ).to be nil
    expect( x.factor     ).to be nil
  end

  it "is Comparable" do
    x = new_speedup( 2.0, 1.0 )
    y = new_speedup( 2.0, 2.0 )
    z = new_speedup( 2.0, 3.0 )

    expect( [ x, z, y ].sort ).to eq( [ z, y, x ] )
  end

  it "is not valid if time is nil" do
    x = new_speedup( nil, nil, -1.0, 2.0 )
    allow( x ).to receive( :time ).and_return nil

    expect( x ).to_not be_valid
  end

  it "is not valid if factor is nil" do
    x = new_speedup( nil, nil, -1.0, 2.0 )
    allow( x ).to receive( :factor ).and_return nil

    expect( x ).to_not be_valid
  end

  it "is valid if time and factor are present (and can't be disproved)" do
    x = new_speedup( nil, nil, -1.0, 2.0 )
    expect( x.time   ).to be_present # precondition check
    expect( x.factor ).to be_present # precondition check

    expect( x ).to be_valid
  end

  it "is not valid if time doesn't agree with timing data" do
    x = new_speedup( 2.0, 1.0, nil, nil )
    allow( x ).to receive( :time ).and_return( 42 )

    expect( x ).to_not be_valid
  end

  it "is not valid if factor doesn't agree with timing data" do
    x = new_speedup( 2.0, 1.0, nil, nil )
    allow( x ).to receive( :factor ).and_return( 42 )

    expect( x ).to_not be_valid
  end

end

