# LabTech!
Rails engine for using GitHub's 'Scientist' library with ActiveRecord, for those of us not operating apps at ROFLscale

Please go read [Scientist's amazing
README](https://github.com/github/scientist/blob/master/README.md).  This tool
won't make any sense until you understand what Scientist is for and how it
works.

If conference videos are your thing, Jesse Toth's ["Easy Rewrites With Ruby and
Science!"](http://www.confreaks.tv/videos/rubyconf2014-easy-rewrites-with-ruby-and-science)
from RubyConf 2014 is well worth your time as well.

## Usage

How to use my plugin.

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

This gem was extracted just before its primary author left Real Geeks, so it's
not quite clear who's going to take responsibility for the gem.  It's probably
a good idea to open a GitHub issue to start a conversation before undertaking
any great amount of work -- though, of course, you're perfectly welcome to fork
the gem and use your modified version at any time.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
