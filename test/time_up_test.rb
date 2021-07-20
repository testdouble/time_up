require "test_helper"

class TimeUpTest < Minitest::Test
  make_my_diffs_pretty!

  def teardown
    TimeUp.delete_all
  end

  def test_that_it_has_a_version_number
    refute_nil ::TimeUp::VERSION
  end

  def test_counts_block_time
    result = TimeUp.start :alpha do
      sleep 0.1
      :some_result
    end
    assert_in_delta 0.1, TimeUp.elapsed(:alpha), 0.02
    assert_equal TimeUp.elapsed(:alpha), TimeUp.timer(:alpha).elapsed
    assert_equal :some_result, result
  end

  def test_counts_without_block
    timer = TimeUp.start :beta
    sleep 0.1
    timer.stop
    assert_in_delta 0.1, TimeUp.elapsed(:beta), 0.02
    assert_equal TimeUp.elapsed(:beta), timer.elapsed

    sleep 0.1

    timer.start
    sleep 0.1
    stop_return_value = timer.stop
    assert_in_delta 0.2, TimeUp.elapsed(:beta), 0.02
    assert_equal TimeUp.elapsed(:beta), timer.elapsed
    assert_equal TimeUp.elapsed(:beta), stop_return_value
  end

  def test_calls_start_and_stop_redundantly
    timer = TimeUp.start :charlie
    timer.start
    second_timer = TimeUp.start :charlie
    assert_same timer, second_timer
    sleep 0.1
    stop_return_1 = timer.stop
    sleep 0.1
    stop_return_2 = timer.stop
    assert_in_delta 0.1, TimeUp.elapsed(:charlie), 0.02
    assert_equal stop_return_1, stop_return_2
  end

  def test_active_timers
    t1 = TimeUp.start :t1
    t2 = TimeUp.start :t2
    t3 = TimeUp.start :t3
    t3.stop

    result = TimeUp.active_timers

    assert_equal [t1, t2], result
    assert t1.active?
    assert t2.active?
    refute t3.active?
  end

  def test_reset
    a = TimeUp.start :a
    b = TimeUp.start :b

    sleep 0.1

    assert_in_delta 0.1, TimeUp.elapsed(:a), 0.02
    assert_in_delta 0.1, TimeUp.elapsed(:b), 0.02

    a.stop
    a.reset
    TimeUp.reset(:b)
    sleep 0.1

    assert_equal 0, a.count
    assert_equal [], a.timings
    assert_equal 0.0, TimeUp.elapsed(:a)
    assert_equal TimeUp.elapsed(:a), a.elapsed
    assert_equal 1, b.count
    assert_in_delta 0.1, TimeUp.timings(:b)[0], 0.02
    assert_in_delta 0.1, TimeUp.elapsed(:b), 0.02
    assert_in_delta TimeUp.elapsed(:b), b.elapsed, 0.01
  end

  def test_stop
    TimeUp.start :z
    result = TimeUp.stop :z

    sleep 0.05

    assert_in_delta 0.0, TimeUp.elapsed(:z), 0.02
    assert_equal TimeUp.elapsed(:z), result
  end

  def test_raises_when_named_timer_doesnt_exist
    e = assert_raises(TimeUp::Error) { TimeUp.elapsed(:fake) }
    assert_equal "No timer named :fake", e.message

    e = assert_raises(TimeUp::Error) { TimeUp.stop(:blah) }
    assert_equal "No timer named :blah", e.message

    e = assert_raises(TimeUp::Error) { TimeUp.reset(:kek) }
    assert_equal "No timer named :kek", e.message

    e = assert_raises(TimeUp::Error) { TimeUp.timings(:hrm) }
    assert_equal "No timer named :hrm", e.message
  end

  def test_raises_if_name_isnt_a_string_or_symbol
    e = assert_raises(TimeUp::Error) { TimeUp.start(42) }
    assert_equal "Timer name must be a String or Symbol", e.message
  end

  def test_elapsed_aggregates_past_plus_active_unless_reset
    TimeUp.start :apple do
      sleep 0.1
    end

    TimeUp.stop :apple

    assert_in_delta 0.1, TimeUp.elapsed(:apple), 0.02

    TimeUp.start :apple
    sleep 0.1

    assert_in_delta 0.2, TimeUp.elapsed(:apple), 0.02
  end

  def test_calling_reset_on_a_running_timer_keeps_running
    TimeUp.start :a
    sleep 0.1
    TimeUp.reset :a
    sleep 0.2
    assert_in_delta 0.2, TimeUp.elapsed(:a), 0.02
  end

  def test_total_elapsed
    TimeUp.start :foo
    TimeUp.start :bar
    TimeUp.start :baz

    sleep 0.1

    assert_in_delta 0.3, TimeUp.total_elapsed, 0.03

    TimeUp.stop :bar
    sleep 0.1
    TimeUp.stop_all

    assert_in_delta 0.5, TimeUp.total_elapsed, 0.04

    sleep 0.1

    assert_in_delta 0.5, TimeUp.total_elapsed, 0.06
    assert_in_delta 0.2, TimeUp.timer(:foo).elapsed, 0.06
    assert_in_delta 0.1, TimeUp.timer(:bar).elapsed, 0.06
    assert_in_delta 0.2, TimeUp.timer(:baz).elapsed, 0.06
  end

  def test_total_elapsed_with_no_timers
    assert_equal 0.0, TimeUp.total_elapsed
  end

  def test_delete_all
    t = TimeUp.start(:t)

    TimeUp.delete_all

    refute_same t, TimeUp.timer(:t)
    assert_equal 0.0, t.elapsed
    refute t.active?
  end

  def test_timer_name_is_accessible
    t = TimeUp.start(:jerry)

    assert_equal :jerry, t.name
  end

  def test_string_timers_dont_blow_up
    t = TimeUp.start("cool neat")

    sleep 0.1

    assert_equal "cool neat", t.name
    assert_in_delta 0.1, TimeUp.elapsed("cool neat"), 0.02
  end

  def test_all_elapsed
    TimeUp.start :t1
    sleep 0.1
    t2 = TimeUp.start :t2
    sleep 0.1
    t2.stop
    TimeUp.start :t3
    sleep 0.1

    result = TimeUp.all_elapsed

    assert_equal 3, result.size
    assert_in_delta 0.3, result[:t1], 0.02
    assert_in_delta 0.1, result[:t2], 0.02
    assert_in_delta 0.1, result[:t3], 0.02
  end

  def test_print_summary
    TimeUp.start :roast
    sleep 0.03
    TimeUp.start :veggies
    sleep 0.02
    TimeUp.start :pasta
    sleep 0.01
    TimeUp.stop_all
    TimeUp.start :souffle

    string_io = StringIO.new
    TimeUp.print_summary(string_io)

    lines = string_io.tap(&:rewind).read.split("\n")

    assert_equal "", lines[0]
    assert_equal "TimeUp summary", lines[1]
    assert_equal "========================", lines[2]
    assert_match(/:roast   	0\.0[567]\d{3}s/, lines[3])
    assert_match(/:veggies 	0\.0[234]\d{3}s/, lines[4])
    assert_match(/:pasta   	0\.0[123]\d{3}s/, lines[5])
    assert_match(/:souffle\*	0\.00\d{3}s/, lines[6])
    assert_equal "", lines[7]
    assert_equal "* Denotes that the timer is still active", lines[8]
  end

  def test_print_detailed_summary
    TimeUp.start :roast
    sleep 0.03
    TimeUp.start :veggies
    sleep 0.02
    TimeUp.start :pasta
    sleep 0.01
    TimeUp.stop_all
    TimeUp.start(:roast) { sleep 0.01 }
    TimeUp.start(:roast) { sleep 0.001 }
    10.times { TimeUp.start(:pasta) {} }
    TimeUp.start :souffle

    string_io = StringIO.new
    TimeUp.print_detailed_summary(string_io)

    lines = string_io.tap(&:rewind).read.split("\n")

    [
      "",
      "=============================================================================",
      "  Name    | Elapsed | Count |   Min   |   Max   |  Mean   | Median  | 95th % ",
      "-----------------------------------------------------------------------------",
      /^:roast    \| 0.0[789]\d{3} \| 3     \| 0.00\d{3} \| 0.0[678]\d{3} \| 0.0[123]\d{3} \| 0.0[123]\d{3} \| 0.0[567]\d{3}/,
      /^:veggies  \| 0.0[234]\d{3} \| 1     \| 0.0[234]\d{3} \| 0.0[234]\d{3} \| 0.0[234]\d{3} \| 0.0[234]\d{3} \| 0.0[234]\d{3}/,
      /^:pasta    \| 0.0[012]\d{3} \| 11    \| 0.00000 \| 0.0[012]\d{3} \| 0.00\d{3} \| 0.00\d{3} \| 0.00\d{3}/,
      /^:souffle\* \| 0.00\d{3} \| 1     \| 0.00\d{3} \| 0.00\d{3} \| 0.00\d{3} \| 0.00\d{3} \| 0.00\d{3}/,
      "",
      "* Denotes that the timer is still active"
    ].each.with_index do |expected, i|
      assert_match expected, lines[i]
    end
  end

  def test_timings
    TimeUp.start(:z) { sleep 0.1 }

    assert_equal 1, TimeUp.timings(:z).size
    assert_in_delta 0.1, TimeUp.timings(:z)[0], 0.01
    assert_equal TimeUp.timer(:z).timings, TimeUp.timings(:z)

    TimeUp.start(:z)
    sleep 0.05

    ongoing_timings = TimeUp.timings(:z)
    assert_equal 2, ongoing_timings.size
    assert_in_delta 0.1, ongoing_timings[0], 0.01
    assert_in_delta 0.05, ongoing_timings[1], 0.01
  end

  def test_empty_stats
    timer = TimeUp.timer(:a)

    assert_equal 0, timer.elapsed
    assert_equal TimeUp.elapsed(:a), timer.elapsed
    assert_equal 0, timer.count
    assert_equal TimeUp.count(:a), timer.count
    assert_equal 0, timer.timings.size
    assert_equal TimeUp.timings(:a).size, timer.timings.size
    assert_nil timer.min
    assert_nil TimeUp.min(:a)
    assert_nil timer.max
    assert_nil TimeUp.max(:a)
    assert_nil timer.mean
    assert_nil TimeUp.mean(:a)
    assert_nil timer.median
    assert_nil TimeUp.median(:a)
    assert_nil timer.percentile(95)
    assert_nil TimeUp.percentile(:a, 95)
  end

  def test_basic_stats_tracking
    timer = TimeUp.timer(:a)
    timer.start { sleep 0.1 }
    timer.start { sleep 0.2 }
    sleep 0.1
    timer.start { sleep 0.1 }
    timer.start { sleep 0.05 }

    assert_in_delta 0.45, timer.elapsed, 0.03
    assert_equal 4, timer.count
    assert_equal 4, timer.timings.size
    assert_in_delta 0.1, timer.timings[0], 0.01
    assert_in_delta 0.2, timer.timings[1], 0.01
    assert_in_delta 0.1, timer.timings[2], 0.01
    assert_in_delta 0.05, timer.timings[3], 0.01
    assert_in_delta 0.05, timer.min, 0.01
    assert_in_delta 0.2, timer.max, 0.01
    assert_in_delta 0.1125, timer.mean, 0.03
    assert_in_delta 0.1, timer.median, 0.02
    assert_equal 0, timer.percentile(0)
    assert_equal 0, timer.percentile(-1.0)
    assert_in_delta 0.2, timer.percentile(100.0), 0.01
    assert_in_delta 0.2, timer.percentile(110.0), 0.01
    assert_in_delta 0.2, timer.percentile(95), 0.03
    assert_in_delta 0.095, timer.percentile(30), 0.03
  end

  def test_all_stats
    TimeUp.start(:a) { sleep 0.05 }
    TimeUp.start(:b) { sleep 0.05 }
    TimeUp.start(:a) { sleep 0.1 }

    result = TimeUp.all_stats

    a = TimeUp.timer(:a)
    b = TimeUp.timer(:b)

    assert_equal({
      a: {
        elapsed: a.elapsed,
        count: 2,
        min: a.min,
        max: a.max,
        mean: a.mean,
        median: a.median,
        "95th": a.percentile(95)
      },
      b: {
        elapsed: b.elapsed,
        count: 1,
        min: b.min,
        max: b.max,
        mean: b.mean,
        median: b.median,
        "95th": b.percentile(95)
      }
    }, result)
  end
end
