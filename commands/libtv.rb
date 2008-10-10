#! /usr/bin/ruby

require 'gserver'
require 'commands/helper'

module LibTV
  QUEUE_FILE = 'tv.queue'
  LOCK_FILE = 'tv.queue.lock'
  LOG_FILE = 'tv.queue.log'

  class TVServ < GServer
    def initialize(port = 21976, host = "0.0.0.0")
      puts "Starting TV notification server."
      @started = Time.now.strftime("%s").to_i
      @clients = []
      @mutex = Mutex.new
      @monitor = nil
      super(port, host, Float::MAX, $stderr, true)
    end

    def bootstrap_client
      queue = []
      class << queue
        def mutex
          @tmutex ||= Mutex.new
        end
      end

      # Create the mutex now.
      queue.mutex

      @mutex.synchronize do
        @clients << queue
        unless @monitor
          @monitor = Thread.new { run_monitor }
        end
      end
      queue
    end

    def run_monitor
      begin
        while true
          open(QUEUE_FILE, 'r+') do |af|
            flock(af, File::LOCK_EX) do |f|
              lines = f.readlines
              f.truncate(0)

              new_lines = lines.find_all do |line|
                if line =~ /^(\d+) .*/
                  start = $1.to_i
                  start >= @started
                end
              end

              clients = @mutex.synchronize { @clients }
              clients.each do |c|
                c.mutex.synchronize do
                  c.push(*new_lines)
                end
              end
            end
          end
          sleep 3
        end
      rescue
        puts "Monitor: #$!"
      end
    end

    def serve(sock)
      queue = nil
      begin
        queue = bootstrap_client()
        while true
          queue.mutex.synchronize do
            queue.each do |q|
              sock.write(q)
              sock.flush
            end
            queue.clear
          end
          sleep 3
        end
      rescue
        puts "Ack: #$!"
      ensure
        if queue
          @mutex.synchronize do
            @clients.delete_if { |q| q.object_id == queue.object_id }
          end
        end
      end
    end
  end

  def flock(file, mode)
    success = file.flock(mode)
    if success
      begin
        res = yield file
        return res
      ensure
        file.flock(File::LOCK_UN)
      end
    end
    nil
  end

  def oflock(filename, mode)
    open(filename, 'w') do |of|
      flock(of, mode) do |f|
        return yield(f)
      end
    end
    nil
  end

  def launch_daemon()
    return if fork()

    begin
      Process.setsid
    ensure
    end

    # Try for a lock, but do not block
    oflock(LOCK_FILE, File::LOCK_EX | File::LOCK_NB) do |f|

      # Be a good citizen:
      logfile = File.open(LOG_FILE, 'w')
      logfile.sync = true
      STDOUT.reopen(logfile)
      STDERR.reopen(logfile)
      STDIN.close()

      # And start the notification server.
      tv = TVServ.new
      tv.start()
      tv.join()
    end
    exit 0
  end

  class TV
    @@tv_args = nil

    def self.parse_tv_args(tvarg)
      return unless tvarg.is_a?(String)

      keys = tvarg.split(':')
      hash = { }
      for k in keys
        self.parse_tv_arg(hash, k)
      end
      hash
    end

    def self.parse_seek_num(seek, num, allow_end=false)
      seekname = seek == '<' ? 'seek-back' : 'seek-after'
      expected = allow_end ? 'number or "$"' : 'number'
      if num !~ /^[-+]?\d+(?:\.\d+)?$/ && (!allow_end || num != '$')
        raise "Bad seek argument for #{seekname}: #{num} (#{expected} expected)"
      end
      num
    end

    def self.parse_tv_arg(hash, key)
      if key == 'cancel' or key == 'nuke'
        hash[key] = 'y'
      else
        prefix = key[0..0]
        rest = key[1 .. -1].strip
        if prefix == '<'
          hash['seekbefore'] = parse_seek_num(prefix, rest)
        elsif prefix == '>'
          hash['seekafter'] = parse_seek_num(prefix, rest, true)
        else
          raise "Unrecognised TV option: #{key}"
        end
      end
    end

    def self.with_tv_opts(argv)
      args, opts = extract_options(argv, 'tv')
      old_args = @@tv_args
      begin
        @@tv_args = parse_tv_args(opts[:tv])
        yield args, opts
      ensure
        @@tv_args = old_args
      end
    end

    def self.request_game(g)
      # Launch a daemon that keeps a server socket open for interested
      # parties (i.e. C-SPLAT) to listen in.
      launch_daemon()

      open(QUEUE_FILE, 'a') do |file|
        flock(file, File::LOCK_EX) do |f|
          # Make sure we're really at eof.
          f.seek(0, IO::SEEK_END)
          stripped = g
          f.puts "#{Time.now.strftime('%s')} #{munge_game(stripped)}"
        end
      end
    end

    def self.request_game_verbosely(n, g, who)
      raise "Cannot request games for TV on PM." if ENV['PRIVMSG']

      summary = short_game_summary(g)
      tv = 'FooTV'

      if @@tv_args && @@tv_args['nuke']
        puts "FooTV playlist clear requested by #{who}."
      else
        suffix = @@tv_args && @@tv_args['cancel'] ? ' cancel' : ''
        puts "#{n}. #{summary}#{suffix} requested for #{tv}."
      end

      g['req'] = ARGV[1]

      if @@tv_args
        for k in @@tv_args.keys
          g[k] = @@tv_args[k]
        end
      end

      request_game(g)
    end
  end
end

include LibTV
