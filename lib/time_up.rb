require_relative "time_up/version"

module TimeUp
  class Error < StandardError; end

  @timers = {}
  def self.start(name, &blk)
    raise Error.new("Timer name must be a String or Symbol") unless name.is_a?(Symbol) || name.is_a?(String)
    timer = @timers[name] ||= Timer.new(name)
    timer.start
    if blk
      blk.call
      timer.stop
    end
    timer
  end

  # Delegate methods
  def self.timer(name)
    @timers[name]
  end

  def self.stop(name)
    __ensure_timer(name)
    @timers[name].stop
  end

  def self.elapsed(name)
    __ensure_timer(name)
    @timers[name].elapsed
  end

  def self.reset(name)
    __ensure_timer(name)
    @timers[name].reset
  end

  # Interrogative methods
  def self.total_elapsed
    @timers.values.sum(&:elapsed)
  end

  def self.all_elapsed
    @timers.values.map { |timer|
      [timer.name, timer.elapsed]
    }.to_h
  end

  def self.active_timers
    @timers.values.select(&:active?)
  end

  def self.print_summary(io = $stdout)
    longest_name_length = @timers.values.map { |t| t.name.inspect.size }.max
    summaries = @timers.values.map { |timer|
      name = "#{timer.name.inspect}#{"*" if timer.active?}".ljust(longest_name_length + 1)
      "#{name}\t#{"%.5f" % timer.elapsed}s"
    }
    io.puts <<~SUMMARY

      TimeUp timers summary
      ========================
      #{summaries.join("\n")}

      #{"* Denotes that the timer is still active\n" if @timers.values.any?(&:active?)}
    SUMMARY
  end

  # Iterative methods
  def self.stop_all
    @timers.values.each(&:stop)
  end

  def self.reset_all
    @timers.values.each(&:reset)
  end

  def self.delete_all
    @timers.values.each { |t| t.reset(force: true) }
    @timers = {}
  end

  # Internal methods
  def self.__ensure_timer(name)
    raise Error.new("No timer named #{name.inspect}") unless @timers[name]
  end

  class Timer
    attr_reader :name

    def initialize(name)
      @name = name
      @start_time = nil
      @elapsed = 0.0
    end

    def start
      @start_time ||= now
    end

    def stop
      if @start_time
        @elapsed += now - @start_time
        @start_time = nil
      end
      @elapsed
    end

    def elapsed
      if active?
        @elapsed + (now - @start_time)
      else
        @elapsed
      end
    end

    def active?
      !!@start_time
    end

    def reset(force: false)
      if force
        @start_time = nil
      elsif !@start_time.nil?
        @start_time = now
      end
      @elapsed = 0.0
    end

    private

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
