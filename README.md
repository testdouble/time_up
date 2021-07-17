# time_up

Ever need to measure the elapsed wall-time for one or more bits of Ruby code,
but don't necessarily want to reach for
[Benchmark](https://ruby-doc.org/stdlib-3.0.1/libdoc/benchmark/rdoc/Benchmark.html) or roll your own ad hoc measurement code?
Try `time_up`!

This gem is especially useful for long-running processes (like test suites) that
have several time-intensive operations that are repeated over the life of the
process and that you want to measure in aggregate. (For example, to see how
much time your test suite spends creating factories, truncating the database, or
invoking a critical code path.)

## Install

Just run `gem install time_up` or add time_up to your Gemfile:

```ruby
gem "time_up"
```

## Usage

Starting a timer is easy! Just call `TimeUp.start`:

```ruby
# Pass a block and time_up will only count the time while the block executes:
TimeUp.start(:factories) do
  # … create some factories
end

# Without a block, a started timer will run until you stop it:
TimeUp.start(:truncation)
# … truncate some stuff
TimeUp.stop(:truncation)
```

To get the total time that's elapsed while the timer has been running, call
`elapsed`:

```ruby
slow_time = TimeUp.elapsed(:slow_code_path)
```

Which will return a `Float` representing the number of seconds that have elapsed
while the timer is running.

Timers aggregate total elapsed time running, just like a digital stopwatch. That
means if you start a timer after it's been stopped, the additional time will be
_added_ to the previous elapsed time:

```ruby
TimeUp.start :eggs
sleep 1
puts TimeUp.stop :eggs # => ~1.0

TimeUp.start :eggs
sleep 1
# To get the elapsed time without necessarily stopping the timer, call `elapsed`
puts TimeUp.elapsed :eggs # => ~2.0

# To reset a timer to 0, call `reset` (if it's running, it'll keep running!)
TimeUp.reset :eggs
sleep 5
puts TimeUp.stop :eggs # => ~5.0
```

When passes without a block, `TimeUp.start` returns an instance of the timer,
which has its own `start`, `stop`, `elaped`, and `reset` methods. If you want to
find that instance later, you can also call `TimeUp.timer(:some_name)`. So the
above example could be rewritten as:

```ruby
egg_timer = TimeUp.start :eggs
sleep 1
puts egg_timer.stop # => ~1.0

egg_timer.start
sleep 1

# To get the elapsed time without necessarily stopping the timer, call `elapsed`
puts egg_timer.elapsed # => ~2.0

# To reset a timer to 0, call `reset` (if it's running, it'll keep running!)
egg_timer.reset
sleep 5
puts egg_timer.stop # => ~5.0
```

Finally, if you're juggling a bunch of timers, you can get a summary report of
them printed for you, like so:

```ruby
TimeUp.start :roast
sleep 0.03
TimeUp.start :veggies
sleep 0.02
TimeUp.start :pasta
sleep 0.01
TimeUp.stop_all

TimeUp.start :souffle

TimeUp.print_summary
```

Which will output something like:

```
TimeUp timers summary
========================
:roast   	0.07267s
:veggies 	0.03760s
:pasta   	0.01257s
:souffle*	0.00003s

* Denotes that the timer is still active
```

## API

This gem defines a bunch of public methods but they're all pretty short and
straightforward, so I'd encourage you to [read the code](/lib/time_up.rb).

### `TimeUp` module

`TimeUp.timer(name)` - Returns the `Timer` instance named `name` (creating it,
if it doesn't exist)

`TimeUp.start(name, [&blk])` - Starts (or restarts) a named
[Timer](#timeuptimer-class). If passed with a block, will return whatever the
block evaluates to. If passed without a block, it will return the timer object

`TimeUp.stop(name)` - Stops the named timer or raises if it's not defined

`TimeUp.reset(name)` - Resets the named timer's elapsed time to 0, effectively
restarting it if it's currently running. Raises if the timer isn't defined.

`TimeUp.elapsed(name)` - Returns a `Float` of the total elapsed seconds that the
named timer has been running (and raises if no timer is defined with the given
`name`)

`TimeUp.timings(name)` - Returns an array of each recorded start-to-stop
duration of the timer (including the current one, if active)

`TimeUp.count(name)` - The number of times the timer has been started and
stopped (including the current timing, if active)

`TimeUp.min(name)` - The shortest recording of the timer (including the current
one, if active)

`TimeUp.max(name)` - The longest recording of the timer (including the current
one, if active)

`TimeUp.mean(name)` - The arithmetic mean of all recorded durations of the timer

`TimeUp.total_elapsed` - Returns a `Float` of the sum of `elapsed` for all the
timers you've created

`TimeUp.all_elapsed` - Returns a hash of timer name keys mapped to their
`elapsed` values. Handy for grabbing a snapshot of the state of things at a
particular point in time without stopping all your timers

`TimeUp.all_stats` - Returns a hash of timer name keys mapped to another
hash of their basic statistics (elapsed time, number of recordings, min, max,
and mean)

`TimeUp.active_timers` - Returns an array of all timers that are currently
running. Useful for detecting cases where you might be counting the same time in
multiple places simultaneously

`TimeUp.print_summary([io])` - Pretty-prints a multi-line summary of all your
timers to standard output (or the provided
[IO](https://ruby-doc.org/core-3.0.1/IO.html))

`TimeUp.stop_all` - Stops all timers

`TimeUp.reset_all` - Resets all timers

`TimeUp.delete_all` - Stops and resets all timers and deletes any internal
reference to them

### `TimeUp::Timer` class

`start` - Starts the timer

`stop` - Stops the timer

`elapsed` - A `Float` of the total elapsed seconds the timer has been running

`timings` - Returns an array of each recorded start-to-stop duration of the
timer (including the current one, if active)

`count` - The number of times the timer has been started and stopped (including
the current timing, if active)

`min` - The shortest recording of the timer (including the current one, if
active)

`max` - The longest recording of the timer (including the current one, if
active)

`mean` - The arithmetic mean of all recorded durations of the timer

`active?` - Returns `true` if the timer is running

`reset(force: false)` - Resets the timer to 0 elapsed seconds. If `force` is
true, will also stop the timer if it's running

## Code of Conduct

This project follows Test Double's [code of
conduct](https://testdouble.com/code-of-conduct) for all community interactions,
including (but not limited to) one-on-one communications, public posts/comments,
code reviews, pull requests, and GitHub issues. If violations occur, Test Double
will take any action they deem appropriate for the infraction, up to and
including blocking a user from the organization's repositories.



