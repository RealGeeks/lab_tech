# LabTech!
Rails engine for using GitHub's 'Scientist' library with ActiveRecord, for those of us not operating apps at ROFLscale

Please go read [Scientist's amazing
README](https://github.com/github/scientist/blob/master/README.md).  This tool
won't make any sense until you understand what Scientist is for and how it
works.

If conference videos are your thing, Jesse Toth's ["Easy Rewrites With Ruby and
Science!"](http://www.confreaks.tv/videos/rubyconf2014-easy-rewrites-with-ruby-and-science)
from RubyConf 2014 is well worth your time as well.

**NOTE:  our examples assume that you have access to the Rails production
console.**  If you work at a company that locks this down, you'll need to write
an administrative back-end UI to enable and disable experiments and review them
for accuracy and performance.  (Please feel free to send those back to us in a
pull request; we simply haven't needed them for ourselves, so they don't
exist yet.)

## Why Scientist?

Scientist is a great tool for trying out changes where:
- comprehensive test coverage is impractical
- your test suite doesn't give you sufficient confidence in your changes
- you want detailed performance data on your proposed alternative(s)

## Why LabTech?

Scientist is amazing at **generating** data, but it assumes you'll develop your
own tools for **recording** and **analyzing** it.  Scientist's README examples
show interactions with StatsD and Redis, but if you're working in a Rails app,
odds are *pretty darn good* that:

1. you already have access to a RDBMS and ActiveRecord, and
2. your throughput isn't so huge that some extra database writes will bring
   said RDBMS to its knees.

If both of those assumptions are true for your application, LabTech might be a
good fit for you -- it records experimental results to the database so they're
easy to query later using ActiveRecord.

(If you're legitimately worried about the I/O load on your RDBMS, you can
always ramp up your LabTech experiments a percentage point or two at a time,
keeping an eye on your performance monitoring tools and scaling back as
needed.)

## Usage

Once you've installed the gem and run its migrations (as described in
"Installation", below), you can start running experiments.

For the purposes of this README, let's say we have a Customer Relationship
Manager (CRM) that lets its users search for leads using some predefined set of
criteria (name, location, favorite food, whatever).  (Any resemblance to an
actual SaaS product we sell here at Real Geeks is... purely coincidental.)

Let's say, too, that the code behind that search started out sort of okay, but
it got worse and worse over time until someone decided it was time for a full
rewrite.  The old search code lives in a method named `Lead.search`, but we've
been working on a replacement that lives in `SpiffySearch.leads`.  The tests
for SpiffySearch are in great shape, and we're confident that we won't be
causing any 500 errors -- but we'd like to use a tool like Scientist to make
sure that SpiffySearch returns the same results in the same order our users
expect.

Stand back -- we're going to try SCIENCE!

The first thing we need is a name for our experiment -- let's just go with
`"spiffy-search"`.

### Deploying an Experiment

```ruby
LabTech.science "spiffy-search" do |exp|
  exp.use { Lead.search(params[:search]) }        # control
  exp.try { SpiffySearch.leads(params[:search]) } # candidate
end
```

Within the block, `exp` is an object that includes the `Scientist::Experiment`
module, so we can use any and all of the tools in the Scientist README.

However, I want to call out a few specific ones as being extremely useful for
this sort of thing.  When working with code that returns interesting objects,
it's a Very Good Idea™ to make use of the `clean` method on the experiment.
It's probably also good to override the default comparison and to provide some
context for the experiment, so let's just redo that block with that in mind:

```ruby
LabTech.science "spiffy-search" do |exp|
  exp.context params: params.to_h

  exp.use { Lead.search(params[:search]) }        # control
  exp.try { SpiffySearch.leads(params[:search]) } # candidate

  exp.compare {|control, candidate| control.map(&:id) == candidate.map(&:id) }
  exp.clean { |records| records.map(&:id) }
end
```

Now that that's done, we can safely commit and deploy this code.  As soon as
that code starts getting run, we'll see a new LabTech::Experiment record in the
database.  However, **the candidate block will never run,** because
LabTech::Experiment records are disabled by default.

### Enabling an Experiment

In order to enable the experiment, we'll need to go into the Rails production
console and run:

```ruby
LabTech.enable "spiffy-search"
```

If we have particularly high search volume and we only want to run the
experiment on a fraction of our requests, the `.enable` method takes an
optional `:percent` keyword argument, which accepts an integer in the range
`(0..100)`.  So to sample only, say, 3% of our searches (selected at random),
we could run this instead:

```ruby
LabTech.enable "spiffy-search", percent: 3
```

### Summarizing Experimental Results

At this point, if you have the [table_print gem](http://tableprintgem.com/)
installed, you can get a quick overview of all of your experiments by running:

```ruby
tp LabTech::Experiment.all
```

Either way, if you want more details on how the experiment is running, you can run:

```ruby
tp LabTech.summarize_results "spiffy-search"
```

This will print a terminal-friendly summary of your experimental results.  I'll
talk more about this summary later, but for now, let's say we were
overconfident, and there's a bug in SpiffySearch that's raising an exception.
The summary will have a line that looks like this:

```
22 of 22 (100.00%) raised errors
```

Ruh roh!

### Summarizing Errors

We run this to see what's up:

```
LabTech.summarize_errors "spiffy-search"
```

And we see something that looks like this, only longer:

```
====================================================================================================
Comparing results for smoke-test:


----------------------------------------------------------------------------------------------------
Result #1
  * RuntimeError:  nope
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
Result #2
  * RuntimeError:  nope
----------------------------------------------------------------------------------------------------

====================================================================================================
```

If you want to see individual backtraces, you can do so by finding and
inspecting indvididual records in the Rails console.  For now, though, let's
say we know where the error is...

### Disabling and Restarting an Experiment

There's no point continuing to collect those exceptions, so we might as well
turn the experiment back off:

```ruby
LabTech.disable "spiffy-search"
```

We fix the exception, deploy the new code, and now we want to start the
experiment over again.  We don't want the previous exceptions cluttering up our
new results, so let's clear out all those observations:

```ruby
exp = LabTech::Experiment.named("spiffy-search")
exp.purge_data
```

(Yes, this is a slightly more cumbersome interface than enabling or summarizing
an experiment.  While deleting data is sometimes necessary, we don't want to
make it easy to do accidentally.)

### Summarizing Experimental Results, Take Two

This time, the output from `LabTech.summarize_results "spiffy-search"` looks
more like this:

```
--------------------------------------------------------------------------------
Experiment: smoke-test
--------------------------------------------------------------------------------
Earliest results: 2019-08-21T11:00:41-10:00
Latest result:    2019-08-21T11:23:31-10:00 (23 minutes)

103 of 106 (97.16%) correct
2 of 106 (1.88%) mismatched
1 of 106 (0.94%) timed out

Median time delta: +0.000s  (90% of observations between -0.000s and +0.000s)

Speedups (by percentiles):
      0%  [           █             ·                         ]    -3.1x
      5%  [             █           ·                         ]    -2.8x
     10%  [             █           ·                         ]    -2.6x
     15%  [              █          ·                         ]    -2.5x
     20%  [              █          ·                         ]    -2.4x
     25%  [               █         ·                         ]    -2.3x
     30%  [               █         ·                         ]    -2.2x
     35%  [                █        ·                         ]    -2.1x
     40%  [                █        ·                         ]    -2.0x
     45%  [                         ·    █                    ]    +1.2x faster
     50%  [ · · · · · · · · · · · · · · · · █ · · · · · · · · ]    +1.8x faster
     55%  [                         ·        █                ]    +2.0x faster
     60%  [                         ·        █                ]    +2.1x faster
     65%  [                         ·         █               ]    +2.2x faster
     70%  [                         ·         █               ]    +2.4x faster
     75%  [                         ·          █              ]    +2.6x faster
     80%  [                         ·          █              ]    +2.6x faster
     85%  [                         ·           █             ]    +2.7x faster
     90%  [                         ·           █             ]    +2.8x faster
     95%  [                         ·            █            ]    +3.0x faster
    100%  [                         ·                        █]    +6.7x faster
--------------------------------------------------------------------------------
```

First off, we see a summary of the time range represented in this experiment.
This is a very simple "first result to last result" view that does not take
into account when the experiment was enabled.

Next, we see some counts.  An individual run of an experiment may have one of
four outcomes:
- "correct" means that both control and candidate were considered equivalent
- "mismatched" means that the candidate returned a different value than the
  control
- "timed out" means that the experiment's run raised a `Timeout::Error`
- "raised error" means that the experiment's run raised anything other than
  `Timeout::Error`

After the counts, we see a bunch of performance data, starting with a line that
says "Median time delta" and includes the 5th and 95th percentile time deltas
as well.  "Time delta" just means the difference in execution time between the
control and the candidate:  negative values are faster, and positive values are
slower.  (The 5th and 95th percentiles are deliberately chosen to keep us from
worrying too much about extreme values that might be outliers.)

The rest of the output is taken up by a chart that attempts to provide a handy
visual chart showing whether the candidate is faster or slower than the
control.  Because it can be hard to remember what the signs signify, this also
includes the word "faster" when the candidate was faster than the control.

### Comparing Mismatches

At this point, we might be curious about any mismatches, and want to
investigate those.  Unfortunately, the chart I showed above was edited by hand
to show what the output might look like if mismatches were present, but as of
this writing I don't actually have any mismatches to show you.  (I promise
that's not a humblebrag.)

However, you can get a quick, if EXTREMELY VERBOSE, listing of the first few
mismatches by running:

```ruby
LabTech.compare_mismatches "spiffy-search", limit: 3
```

(To view all mismatches, just leave off the `limit: 3`.)

You have the ability to customize the output of this by passing a block that
takes a "control" parameter followed by a "candidate" parameter; the return
value of that block will be printed to the console.  How you do this will
largely depend on the kind of data you're collecting to validate your
experiments.  There are several examples in the `lib/lab_tech.rb` file; I
encourage you to check them out.

If you have errors to inspect as well, you can view these with:

```ruby
LabTech.summarize_errors "spiffy-search"
```

Note that the `summarize_errors` method also takes an optional `:limit` keyword
argument.

### A Note About Experimental Design

Scientist supports experiments with more than one candidate at a time, and
therefore so does LabTech -- it will record as many candidates as you throw at
it.  However, if you have multiple candidates, we don't have a good way to
generate performance charts to compare all of the alternatives, so LabTech just
doesn't bother printing them.  **If you try this, you're on your own.**  (But
do let us know how it goes, and feel free to submit a PR if you find a good
solution!)

## Installation

**NOTE: As this gem is a Rails engine, we assume you have a Rails application to
include it in.**

Add this line to your application's Gemfile:

```ruby
gem 'lab_tech'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install lab_tech
```

Once the gem is installed, run this from your application's root (possibly with
the `bundle exec` or `bin/` prefix, or whatever else may be dictated by your
local custom and practice):

```ruby
rails lab_tech:install:migrations db:migrate
```

The output from that command should look like this:

```
Copied migration 20190822175815_create_experiment_tables.lab_tech.rb from lab_tech
== 20190822175815 CreateExperimentTables: migrating ===========================
-- create_table("lab_tech_experiments")
-> 0.0147s
-- create_table("lab_tech_results")
-> 0.0152s
-- create_table("lab_tech_observations")
-> 0.0109s
== 20190822175815 CreateExperimentTables: migrated (0.0410s) ==================
```

Once that's done, you should be good to go!  See the "Usage" section, above.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/RealGeeks/lab_tech.

It's probably a good idea to open a GitHub issue to start a conversation before
undertaking any significant amount of work -- though, as always with F/OSS
code, you're perfectly welcome to fork the gem and use your modified version at
any time.

This project is intended to be a safe, welcoming space for collaboration.
While we have not yet formally adopted a code of conduct, it's probably a Very
Good Idea to act in accordance with the <a
href="https://www.contributor-covenant.org/">Contributor Covenant</a>.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
