require 'open-uri'
require 'net/http'
require 'timeout'

# Helps you spinning up and shutting down your own sinatra app. This is especially helpful for running
# real network tests against a sinatra backend.
#
# The backend server could look like the following (in test/server.rb).
#
#   require "sinatra"
#
#   get "/" do
#     "Cheers from test server"
#   end
#
#   get "/ping" do
#     1
#   end
#
# Note that you need to implement a ping action for internal use.
#
# Next, you need to write your runner.
#
#   require 'sinatra/runner'
#
#   class Runner < Sinatra::Runner
#     def app_file
#       File.expand_path("../server.rb", __FILE__)
#     end
#   end
#
# Override Runner#app_file, #command, #port and #ping_path for customization.
#
# Whereever you need this test backend, here's how you manage it. The following example assumes you
# have a test in your app that needs to be run against your test backend.
#
#   runner = ServerRunner.new
#   runner.run
#
#   # ..tests against localhost:4567 here..
#
#   runner.kill
#
# For an example, check https://github.com/apotonick/roar/blob/master/test/test_helper.rb
module Sinatra
  class Runner
    def app_file
      File.expand_path("../server.rb", __FILE__)
    end

    def run
      #puts command
      @pipe     = start
      @started  = Time.now
      warn "#{server} up and running on port #{port}" if ping
    end

    def kill
      return unless pipe
      Process.kill("KILL", pipe.pid)
    rescue NotImplementedError
      system "kill -9 #{pipe.pid}"
    rescue Errno::ESRCH
    end

    def get(url)
      Timeout.timeout(1) { open("http://127.0.0.1:#{port}#{url}").read }
    end

    def log
      @log ||= ""
      loop { @log <<  pipe.read_nonblock(1) }
    rescue Exception
      @log
    end

  private
    attr_accessor :pipe

    def start
      IO.popen(command)
    end

    def command # to be overwritten
      "bundle exec ruby #{app_file} -p #{port} -e production"
    end

    def ping(timeout=30)
      loop do
        return if alive?
        if Time.now - @started > timeout
          $stderr.puts command, log
          fail "timeout"
        else
          sleep 0.1
        end
      end
    end

    def alive?
      3.times { get(ping_path) }
      true
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, SystemCallError, OpenURI::HTTPError, Timeout::Error
      false
    end

    def ping_path # to be overwritten
      '/ping'
    end

    def port # to be overwritten
      4567
    end
  end
end