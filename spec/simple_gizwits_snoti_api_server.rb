require 'socket'
require 'openssl'
require "json"
require "pry"

class SimpleGizwitsSnotiApiServer
	def initialize(options)
		@host = options[:host]
		@port = options[:port]
		@products = options[:products]
		@tcp_server = nil
		@thread = nil
	end

	def start
		@tcp_server = TCPServer.new(@host, @port)
    ssl_context = OpenSSL::SSL::SSLContext.new
    key_file = File.join(File.dirname(__FILE__), '', "server.key")
    pem_file = File.join(File.dirname(__FILE__), '', "server.pem")
    ssl_context.set_params({
    	cert: OpenSSL::X509::Certificate.new(File.read(pem_file)),
    	key: OpenSSL::PKey::RSA.new(File.read(key_file))
    })
    @tcp_server = OpenSSL::SSL::SSLServer.new(@tcp_server, ssl_context)

    @thread = Thread.new do
    	loop do
    		handle_request(@tcp_server.accept)
    	end
    end
	end

	def close
		@tcp_server.close
		@thread.kill if !@thread.nil?
		@thread = nil
	end

	private
	def handle_request(client)
		while (request_string = client.gets) do
			begin
				request = JSON.parse(request_string)

				case request["cmd"]
				when "login_req"
					res = {
						cmd: "login_res",
						data: {
							result: true,
							msg: "ok"
						}
					}

					first_req = request["data"].first
					first_p = @products.first
					if !(first_req["product_key"] == first_p[:product_key] && first_req["auth_id"] == first_p[:auth_id] && first_req["auth_secret"] == first_p[:auth_secret])
						res[:data][:result] = false
						res[:data][:msg] = "bad auth"
					end

					client.puts(res.to_json + "\n")

					if res[:data][:result]
						sleep 1

						if first_req["events"].include?("device_status_raw")
							client.puts({
								"cmd": "event_push",
								"delivery_id": 1,
								"event_type": "device_status_raw",
								"did": "1111111111111111", 
								"created_at": 1.49994106739599990845e+09, 
								"product_key": "123456789abcdefgh", 
								"mac": "999999999999", 
								"group_id": nil, 
								"data": {
									"raw": "MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkw"
								}
							}.to_json  + "\n")
						end
					end
				when "remote_control_req"
					res = {
						cmd: "remote_control_res",
						result: {
							succeed: [],
							failed:[]
						}
					}
					request["data"].each do |rcr|
						case rcr["cmd"]
						when "write", "write_v1"
							res[:result][:succeed] << rcr["data"]["did"]
						when "write_attrs"
							res[:result][:succeed] << rcr["data"]["did"]
						end
					end
					client.puts(res.to_json + "\n")
				when "ping"
					client.puts({cmd: "pong"}.to_json + "\n")
				when "event_ack"

				end
						
			rescue Exception => e
				client.puts({cmd: "invalid_msg", error_code: 1000, msg: e.to_s}.to_json + "\n")
			end
		end
	end
end