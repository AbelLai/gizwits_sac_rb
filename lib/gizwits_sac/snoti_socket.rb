require "socket"
require "openssl"
require "json"

# GizwitsSac = Gizwits Snoti API Client
module GizwitsSac
	# options = {
	# 	host: "xxx",
	# 	port: "xxx",
	# 	connect_timeout: xx,
	# 	read_timeout: xx,
	# 	write_timeout: xx,
	# 	prefetch_count: xx,
	# 	auth_data: [
	# 		{
	# 			product_key: "xxxx",
	# 			auth_id: "xxxx",
	# 			auth_secret: "xxxx",
	# 			subkey: "xxxx",
	# 			events: ['xxx', 'xxx']
	# 		}
	# 	]
	# }
	class SnotiSocket
		def initialize(options)
			@host = options[:host]
			@port = options[:port]
			@timeout = options[:connect_timeout] || 3
			@read_timeout = options[:read_timeout] || @timeout
			@write_timeout = options[:write_timeout] || @timeout
			@prefetch_count = options[:prefetch_count] || 50
			@auth_data = options[:auth_data]
			@socket = nil
			@ssl_socket = nil
			@lf = "\n"
			@buffer = "".dup
		end

		def connect
			socket_connect
			ssl_connect
		end

		def read(n_bytes = 1)
			index = nil
			while (index = @buffer.index(@lf)) == nil
				@buffer << read_data(n_bytes)
			end
			@buffer.slice!(0, index + @lf.bytesize)
		end

		def write(data)
			write_data(data)
		end

		def closed?
			@socket.nil? && @ssl_socket.nil?
		end

		def login_ok?
			req_msg = "{\"cmd\":\"login_req\",\"prefetch_count\": #{@prefetch_count},\"data\": #{@auth_data.to_json}}"
			write(req_msg)
			resp =JSON.parse(read)
			succeed = resp["data"]["result"]
			# close connection if login failed
			close if !succeed
			return succeed
		end

		def remote_control(data_arr, msg_id = nil)
			req = { cmd: "remote_control_req", data: data_arr }
			req[:msg_id] = msg_id if !msg_id.nil?
			write(req.to_json)
		end

		def ping
			write("{\"cmd\": \"ping\"}")
		end

		def ack(delivery_id)
			write("{\"cmd\": \"event_ack\",\"delivery_id\": #{delivery_id}}")
		end

		def close
			@ssl_socket.close if (!@ssl_socket.nil? && !@ssl_socket.closed?)
			@ssl_socket = nil
			@socket.close if (!@socket.nil? && !@socket.closed?)
			@socket = nil
		end

		private

		def socket_connect
			addr = Socket.getaddrinfo(@host, nil)
			socket_addr = Socket.pack_sockaddr_in(@port, addr[0][3])
			
			@socket = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0).tap do |socket|
				socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

				begin
					begin
						non_blocking(socket, build_deadline(@timeout)) { socket.connect_nonblock(socket_addr) }
					rescue Errno::EISCONN
						# TODO: nothing to do
					rescue ConnTimeoutError
						raise ConnTimeoutError
					end
				rescue ConnTimeoutError => timeout_ex
					raise ConnTimeoutError
				rescue SystemCallError, IOError => exception
					raise ConnFailedError.new("socket connection failed with exception: #{exception}")
				end
			end		
		end

	  def non_blocking(socket, deadline)
	      yield
	    rescue IO::WaitReadable
	    	timeout = check_deadline(deadline)
	      raise ConnTimeoutError unless IO.select([socket], nil, nil, timeout)
	      retry
	    rescue IO::WaitWritable
	    	timeout = check_deadline(deadline)
	      raise ConnTimeoutError unless IO.select(nil, [socket], nil, timeout)
	      retry
	  end

	  def check_deadline(deadline)
	  	remaining = deadline - Time.now.utc
	  	raise ConnTimeoutError if remaining < 0
	  	return remaining
	  end

	  def build_deadline(timeout)
	  	Time.now.utc + timeout
	  end

		def ssl_connect
	    ssl_context = OpenSSL::SSL::SSLContext.new
	    ssl_context.set_params({verify_mode: OpenSSL::SSL::VERIFY_NONE})

	    @ssl_socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
	    @ssl_socket.sync_close = true

			ssl_socket_connect("ssl connection failed.", @timeout) {@ssl_socket.connect_nonblock}
		end

		def ssl_socket_connect(failed_desc, timeout)
	    begin
				begin
					non_blocking(@ssl_socket, build_deadline(timeout)) { yield }
				rescue Errno::EISCONN
					# TODO: nothing to do
				rescue ConnTimeoutError
					raise ConnTimeoutError
				end
			rescue ConnTimeoutError => timeout_ex
				raise ConnTimeoutError
			rescue SystemCallError, OpenSSL::SSL::SSLError, IOError => exception
				raise ConnFailedError.new("#{failed_desc}\n Exception trace: #{exception}")
			end			
		end

		def write_data(data)
			ssl_socket_connect("write data failed.", @write_timeout) {@ssl_socket.write_nonblock("#{data}\n")}
		end

		def read_data(n_bytes)
			ssl_socket_connect("read data failed.", @read_timeout) {@ssl_socket.read_nonblock(n_bytes)}
		end
	end	
end
