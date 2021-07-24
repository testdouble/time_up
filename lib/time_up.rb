require_relative "time_up/version"

module TimeUp
  class Error < StandardError; end

  Thread.current[:time_up_timers] = {}

  def self.timer(name)
    __timers[name] ||= Timer.new(name)
  end

  # Delegate methods
  def self.start(name, &blk)
    timer(name).start(&blk)
  end

  [
    :stop,
    :reset,
    :elapsed,
    :timings,
    :count,
    :min,
    :max,
    :mean,
    :median
  ].each do |method_name|
    define_singleton_method method_name do |name|
      __ensure_timer(name)
      __timers[name].send(method_name)
    end
  end

  def self.percentile(name, percentage)
    __ensure_timer(name)
    __timers[name].percentile(percentage)
  end

  # Interrogative methods
  def self.total_elapsed
    __timers.values.sum(&:elapsed)
  end

  def self.all_elapsed
    __timers.values.map { |timer|
      [timer.name, timer.elapsed]
    }.to_h
  end

  def self.all_timers
    __timers.values
  end

  def self.all_stats
    __timers.values.map { |timer|
      [timer.name, {
        elapsed: timer.elapsed,
        count: timer.count,
        min: timer.min,
        max: timer.max,
        mean: timer.mean,
        median: timer.median,
        "95th": timer.percentile(95)
      }]
    }.to_h
  end

  def self.active_timers
    __timers.values.select(&:active?)
  end

  def self.print_summary(io = $stdout)
    longest_name_length = __timers.values.map { |t| t.name.inspect.size }.max
    summaries = __timers.values.map { |timer|
      name = "#{timer.name.inspect}#{"*" if timer.active?}".ljust(longest_name_length + 1)
      "#{name}\t#{"%.5f" % timer.elapsed}s"
    }
    io.puts <<~SUMMARY

      TimeUp summary
      ========================
      #{summaries.join("\n")}

      #{"* Denotes that the timer is still active\n" if __timers.values.any?(&:active?)}
    SUMMARY
  end

  def self.print_detailed_summary(io = $stdout)
    cols = {
      names: ["Name"],
      elapsed: ["Elapsed"],
      count: ["Count"],
      min: ["Min"],
      max: ["Max"],
      mean: ["Mean"],
      median: ["Median"],
      "95th": ["95th %"]
    }
    __timers.values.each { |timer|
      cols[:names] << "#{timer.name.inspect}#{"*" if timer.active?}"
      cols[:elapsed] << "%.5f" % timer.elapsed
      cols[:count] << timer.count.to_s
      cols[:min] << "%.5f" % timer.min
      cols[:max] << "%.5f" % timer.max
      cols[:mean] << "%.5f" % timer.mean
      cols[:median] << "%.5f" % timer.median
      cols[:"95th"] << "%.5f" % timer.percentile(95)
    }

    widths = cols.map { |name, vals|
      [name, vals.map(&:length).max]
    }.to_h

    rows = cols[:names].size.times.map { |i|
      if i == 0
        cols.keys.map { |name|
          cols[name][i].center(widths[name])
        }
      else
        cols.keys.map { |name|
          cols[name][i].ljust(widths[name])
        }
      end
    }

    full_width = widths.values.sum + (rows[0].size - 1) * 3
    io.puts <<~SUMMARY

      #{"=" * full_width}
      #{rows[0].join(" | ")}
      #{"-" * full_width}
      #{rows[1..-1].map { |row| row.join(" | ") }.join("\n")}

      #{"* Denotes that the timer is still active\n" if __timers.values.any?(&:active?)}
    SUMMARY
  end

  # Iterative methods
  def self.stop_all
    __timers.values.each(&:stop)
  end

  def self.reset_all
    __timers.values.each(&:reset)
  end

  def self.delete_all
    __timers.values.each { |t| t.reset(force: true) }
    Thread.current[:time_up_timers] = {}
  end

  # Internal methods
  def self.__timers
    Thread.current[:time_up_timers] ||= {}
  end

  def self.__ensure_timer(name)
    raise Error.new("No timer named #{name.inspect}") unless __timers[name]
  end

  class Timer
    attr_reader :name

    def initialize(name)
      validate!(name)
      @name = name
      @start_time = nil
      @total_elapsed = 0.0
      @past_timings = []
    end

    def start(&blk)
      @start_time ||= now
      if blk
        blk.call.tap do
          stop
        end
      else
        self
      end
    end

    def stop
      if @start_time
        duration = now - @start_time
        @past_timings.push(duration)
        @total_elapsed += duration

        @start_time = nil
      end
      @total_elapsed
    end

    def elapsed
      if active?
        @total_elapsed + (now - @start_time)
      else
        @total_elapsed
      end
    end

    def reset(force: false)
      if force
        @start_time = nil
      elsif !@start_time.nil?
        @start_time = now
      end
      @total_elapsed = 0.0
      @past_timings = []
    end

    def count
      timings.size
    end

    def min
      timings.min
    end

    def max
      timings.max
    end

    def mean
      times = timings
      return if times.empty?
      times.sum / times.size
    end

    def median
      times = timings.sort
      return if times.empty?
      (times[(times.size - 1) / 2] + times[times.size / 2]) / 2.0
    end

    def percentile(percent)
      times = timings.sort
      return if times.empty?
      return 0 if percent <= 0
      return max if percent >= 100
      return times.first if times.size == 1
      position = (percent / 100.0) * (times.size - 1)

      partial_ratio = position - position.floor
      whole, partial = times[position.floor, 2]
      whole + (partial - whole) * partial_ratio
    end

    def timings
      if active?
        @past_timings + [now - @start_time]
      else
        @past_timings
      end
    end

    def active?
      !!@start_time
    end

    private

    def validate!(name)
      unless name.is_a?(Symbol) || name.is_a?(String)
        raise Error.new("Timer name must be a String or Symbol")
      end
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
