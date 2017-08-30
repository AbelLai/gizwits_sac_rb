require "spec_helper"
require "simple_gizwits_snoti_api_server"

describe GizwitsSac do
  it "has a version number" do
    expect(GizwitsSac::VERSION).not_to be nil
  end

  describe GizwitsSac::SnotiSocket do
  	describe "#connection" do
  		it "raises an exception if server is unavailable" do
  			begin
  				GizwitsSac::SnotiSocket.new({host: "localhost", port: 3000}).connect
  			rescue GizwitsSac::ConnFailedError => e
  				expect(e.class).to eq GizwitsSac::ConnFailedError
  			end
  		end

  		it "raies an exception if time out" do
  			simple_snoti_server = TCPServer.new("localhost", 2017)

  			begin
  				GizwitsSac::SnotiSocket.new({host: "localhost", port: 2017}).connect
  			rescue GizwitsSac::ConnTimeoutError => e
  				expect(e.class).to eq GizwitsSac::ConnTimeoutError
  			end
  		end
  	end

  	describe "#with_server" do
  		before do
  			@server = SimpleGizwitsSnotiApiServer.new({
  				host: "localhost",
  				port: 20171,
  				products: [{
						product_key: "123456789abcdefgh",
						auth_id: "123456789abcdefgh",
						auth_secret: "123456789abcdefgh"
					}]
  			})

  			@server.start
  		end

  		after do
  			@server.close if !@server.nil?
  			@client.close if !@client.nil?
  		end

  		describe "#login" do
	  		it "login successfully if auth data is valid" do
		  			@client = GizwitsSac::SnotiSocket.new({
		  				host: "localhost", 
		  				port: 20171,
		  				connect_timeout: 20,
		  				auth_data: [{
								product_key: "123456789abcdefgh",
								auth_id: "123456789abcdefgh",
								auth_secret: "123456789abcdefgh",
								subkey: "123456789abcdefgh",
								events: ['device.status.raw']
							}]
						})

						@client.connect
						expect(@client.login_ok?).to eq true
	  		end

	  		it "donot login successfully if auth data something invalid" do
		  			@client = GizwitsSac::SnotiSocket.new({
		  				host: "localhost", 
		  				port: 20171,
		  				connect_timeout: 20,
		  				auth_data: [{
								product_key: "123456789abcdefgh",
								auth_id: "123456789abcdefgh",
								auth_secret: "123456789abcdefgh_11111",
								subkey: "123456789abcdefgh",
								events: ['device.status.raw']
							}]
						})

						@client.connect
						expect(@client.login_ok?).to eq false
	  		end	  		  			
  		end
  	end
  end
end
