# 0.0.5

- Add `median` and `percentile` timer statistics, and added them to
  `print_detailed_summary`

# 0.0.4

- Add `TimeUp.print_detailed_summary`

# 0.0.3

- Change the return value of TimeUp.start when passed a block to be the
  evaluated value of the block (for easier insertion into existing code without
  adding a bunch of new assignment and returns)
- Allow timer instances' `start` method to be called with a block
- Add `timings`, `count`, `min`, `max`, and `mean` methods for basic stats
  tracking
- Add `TimeUp.all_stats` to roll up all these

# 0.0.2

- Switch from a module method to Thread.current variable

# 0.0.1

- Make the gem


