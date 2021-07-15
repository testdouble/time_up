require "test_helper"

class TimeUpTest < Minitest::Test
  def teardown
    TimeUp.delete_all
  end

  def test_that_it_has_a_version_number
    refute_nil ::TimeUp::VERSION
  end

  def test_counts_block_time
    timer = TimeUp.start :alpha do
      sleep 0.1
    end
    assert_in_delta 0.1, TimeUp.elapsed(:alpha), 0.02
    assert_equal TimeUp.elapsed(:alpha), timer.elapsed
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

    assert_equal 0.0, TimeUp.elapsed(:a)
    assert_equal TimeUp.elapsed(:a), a.elapsed
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
    sleep 0.1

    TimeUp.delete_all

    assert_nil TimeUp.timer(:t)
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
    assert_equal "TimeUp timers summary", lines[1]
    assert_equal "========================", lines[2]
    assert_match(/:roast   	0\.0[567]\d{3}s/, lines[3])
    assert_match(/:veggies 	0\.0[234]\d{3}s/, lines[4])
    assert_match(/:pasta   	0\.0[123]\d{3}s/, lines[5])
    assert_match(/:souffle\*	0\.00\d{3}s/, lines[6])
    assert_equal "", lines[7]
    assert_equal "* Denotes that the timer is still active", lines[8]
  end
end
