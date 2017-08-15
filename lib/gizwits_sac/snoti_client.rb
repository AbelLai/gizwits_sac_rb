require "logger"
require "thread"

# Example for params when new a SnotiClient:
#   options = {
#   	event_push: (Proc.new {|event_push_data| }),
#   	remote_ctrl: (Proc.new { return nil }),
#     remote_ctrl_res: (Proc.new {|r_ctrl_data| }),
#     error_res: (Proc.new {|err_data| }),
#     heartbeat_interval: 60,
#     logger: Logger.new("xxxx"),
#   	retry_count: 10,
#   	host: "xxx",
#   	port: "xxx",
#   	timeout: 3,
#   	read_timeout: 3,
#   	write_timeout: 3,
#   	prefetch_count: 50,
#   	auth_data: [
#   		{
#   			product_key: "xxxx",
#   			auth_id: "xxxx",
#   			auth_secret: "xxxx",
#   			subkey: "xxxx",
#   			events: ['xxx', 'xxx']
#   		}
#   	]	
#   }

# GizwitsSac = Gizwits Snoti API Client
module GizwitsSac
	class SnotiClient
		def initialize(options)
			@event_push = options.delete(:event_push) || (Proc.new {|event_push_data| })
			@remote_ctrl = options.delete(:remote_ctrl) || (Proc.new { return nil })
			@remote_ctrl_res = options.delete(:remote_ctrl_res) || (Proc.new {|r_ctrl_data| })
			@error_res = options[:error_res] || (Proc.new {|err_data| })
			@retry_count = options.delete(:retry_count) || 5
			@heartbeat_interval = options.delete(:heartbeat_interval) || 60
			@logger = options.delete(:logger) || Logger.new(STDOUT)
			@heartbeat_thread = nil
			@remote_ctrl_thread = nil
			@socket = SnotiSocket.new(options)
			@exited = false
		end

		def start
			listen_shut_down

			connect_count = 0
			begin
				connect_count += 1
				# 1. Connect to Gizwits Snoti API
				@socket.connect
				# 2. Login to Gizwits Snoti API and Check
				if @socket.login_ok?
					# 3. Exchange data via SnotiSocket
					exchange
				else
					raise LoginError
				end				
			rescue Exception => e
				if connect_count < @retry_count
					retry
				else
					# It needs to kill the backgroud thread after all retry failed
					dispose
					raise e
				end
			end
		end

		private
		def exchange
			# 1. Start heartbeat
			heartbeat
			# 2. Start remote control in another thread
			invoke_remote_ctrl
			# 3. Loop and fetch data from Gizwits Snoti API
			smart_read
		end

		# Base on Gizwits Snoti API, it would be one message which detected by '\n'.
		# So sometimes it needs to get the message via length = 1 when the app's data flow is not large.
		def smart_read
			nbytes = 100
			receive_total_by_one_byte = 0
			begin
				loop do
					if !@exited
						handle_snoti_data(@socket.read(nbytes))
						(receive_total_by_one_byte += 1) if (nbytes == 1)
						(nbytes, receive_total_by_one_byte = 100, 0) if (receive_total_by_one_byte >= 100)
					else
						break
					end
				end
			rescue ConnTimeoutError, ReadTimeoutError => timeout_ex
				nbytes, receive_total_by_one_byte = 1, 0
				retry
			rescue Exception => ex
				raise ex
			end
		end

	  def handle_snoti_data(noti_data)
			json_data = JSON.parse(noti_data)

	    case json_data["cmd"]
	    when "event_push"
	    	@socket.ack(json_data['delivery_id'])
	    	@event_push.call(json_data)
	    when "remote_control_res"
	    	@remote_ctrl_res.call(json_data)
	    when "invalid_msg"
	    	@error_res.call(json_data)
	    when "pong"
	    	# Nothing to do
	    end
	  end

	  # Keep heartbeat to Gizwits Snoti API every 60 seconds in backgroud thread
	  def heartbeat
	  	if @heartbeat_thread.nil?
	  		@heartbeat_thread = every(60) do
	  			begin
	  				@socket.ping if !@exited
	  			rescue Exception => e
	  				@logger.error("[Heartbeat Error] ====> #{e}")
	  			end

	  			# If it catch system exit signal, return true to break the loop
	  			is_break = @exited
	  			is_break
	  		end
	  	end
	  end 

	  # Handle remote control request to Gizwits Snoti API in backgroud thread
	  def invoke_remote_ctrl
	  	if @remote_ctrl_thread.nil?
	  		@remote_ctrl_thread = loop_after(2) do
  				if !@exited
	  				begin
		  				r_ctrl_req = @remote_ctrl.call
		  				if r_ctrl_req.nil?
		  					sleep 1
		  				else
		  					@logger.info("[Remote Control] ====> #{r_ctrl_req}")
		  					@socket.remote_control(r_ctrl_req)
		  				end
	  				rescue Exception => e
	  					@logger.error("[Remote Control Error] =====> #{e}")
	  				end
	  			end

	  			# If it catch system exit signal, return true to break the loop
	  			is_break = @exited
	  			is_break
	  		end
	  	end
	  end

	  def every(interval)
	  	Thread.new { loop { sleep interval; break if yield } }
	  end

	  def loop_after(seconds)
	  	Thread.new { sleep seconds; loop { break if yield } }
	  end

	  def dispose
	  	if @remote_ctrl_thread.nil?
	  		@remote_ctrl_thread.kill
	  		@remote_ctrl_thread = nil
	  	end

	  	if @heartbeat_thread.nil?
	  		@heartbeat_thread.kill
	  		@heartbeat_thread = nil
	  	end	  	
	  end

	  def listen_shut_down
	  	# Trap ^C
  		Signal.trap('INT') { @exited = true }
  		# Trap `Kill`
  		Signal.trap('TERM') { @exited = true }
	  end
	end
end