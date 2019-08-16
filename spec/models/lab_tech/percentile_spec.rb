require 'rails_helper'

RSpec.describe LabTech::Percentile do
  # Just keep walking, Mr. Phippen, and nobody gets hurt. ;P
  def self.expect_percentile( percentile, expected_value )
    specify "percentile(#{percentile}) should be #{expected_value}" do
      expect( LabTech::Percentile.call(percentile, array) ).to eq( expected_value )
    end
  end

  def self.expect_percentiles(percentiles_to_values = {})
    percentiles_to_values.each do |percentile, value|
      expect_percentile percentile, value
    end
  end

  describe "examples I swiped from Wikipedia" do
    # Specifically: https://en.wikipedia.org/wiki/Percentile#The_nearest-rank_method
    context "for a 5-item array" do
      subject(:array) { [ 15, 20, 35, 40, 50 ] }

      expect_percentiles({
        0   => 15,
        20  => 15,
        21  => 20,
        40  => 20,
        41  => 35,
        60  => 35,
        61  => 40,
        80  => 40,
        81  => 50,
        100 => 50,
      })

    end

    context "for a 10-item array" do
      subject(:array) { [ 3, 6, 7, 8, 8, 10, 13, 15, 16, 20 ] }

      expect_percentiles({
        25  => 7,
        50  => 8,
        75  => 15,
        100 => 20,
      })
    end

    context "for an 11-item array" do
      subject(:array) { [ 3, 6, 7, 8, 8, 9, 10, 13, 15, 16, 20 ] }

      expect_percentiles({
        25  => 7,
        50  => 9,
        75  => 15,
        100 => 20,
      })

    end
  end

  context "for a 100-item array" do
    subject(:array) { (1..100).to_a }

    expect_percentiles({
      0   =>   1,
      1   =>   1,
      2   =>   2,
      99  =>  99,
      100 => 100,
    })
  end

  context "for a 1000-item array" do
    subject(:array) { (1..1000).to_a }

    expect_percentiles({
      0   => 1,
      1   => 10,
      50  => 500,
      99  => 990,
      100 => 1000,
    })

  end
end
