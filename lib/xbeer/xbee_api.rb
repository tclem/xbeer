require 'xbeer/xbee'
require 'xbeer/frame'
require 'pp'

module Xbeer
  
  class XbeeApi < Xbee
    
    def initialize(opts={})
      super(opts)
      
      no_setup = opts[:no_setup] | false
      begin
        r = write_at_cmd "AP2"
        puts "ensuring api mode (AP = 2): #{r}"
        save!
        write_at_cmd "CN"   # exit command mode (this applies changes too)
      end unless no_setup
      
      @frame_id = 0x52
    end
    
    def read_api
      stray_bytes = []
      until (start_delimiter = @s.readchar) == 0x7e
        puts "Stray byte 0x%x" % start_delimiter
        stray_bytes << start_delimiter
      end
      puts "Got some stray bytes for ya: #{stray_bytes.map {|b| "0x%x" % b} .join(", ")}" unless stray_bytes.empty?
      header = @s.read(3).xb_unescape
      puts "Read header: #{header.unpack("C*").join(", ")}"
      frame_remaining = frame_length = api_identifier = cmd_data = ""
      if header.length == 3
        frame_length, api_identifier = header.unpack("nC")
      else
        frame_length, api_identifier = header.unpack("n").first, @s.readchar
      end
      cmd_data_intended_length = frame_length - 1
      while ((unescaped_length = cmd_data.xb_unescape.length) < cmd_data_intended_length)
        cmd_data += @s.read(cmd_data_intended_length - unescaped_length)
      end
      data = api_identifier.chr + cmd_data.xb_unescape
      sent_checksum = @s.getc
      unless sent_checksum == Frame.checksum(data)
        raise "Bad checksum - data discarded"
      end
      puts "Raw response: 0x#{data.unpack("H*")}"
      data
    end
    
    def send_at_cmd(cmd)
      f = Frame.new(0x08, [@frame_id, cmd].pack("ca*"))
      puts "Sending this frame: 0x#{f.to_frame.unpack("H*")}"
      @s.write f.to_frame
      r = ATCommandResponse.new(read_api)
      # puts "Got this reponse:"
      # pp r
      puts "AT Command Response Value: 0x#{r.retrieved_value.unpack("H*")}"
    end
    
    def tx(dest_addr=0x000000000000FFFF, data="")
      dest_high = (dest_addr >> 32) & 0xFFFFFFFF
      dest_low = dest_addr & 0xFFFFFFFF
      f = Frame.new(0x00, [@frame_id, dest_high, dest_low, 0x00, data].pack("cNNca*"))
      puts "Sending this frame: 0x#{f.to_frame.unpack("H*")}"
      @s.write f.to_frame
      r = TransmitStatusResponse.new(read_api)
      pp r
      puts "tx was successful" if r.status == :OK
      r
    end
    
    def rx
      pp r = ReceivePacket.new(read_api)
      r
    end
    
    def exit_api_mode
      sleep 1.2
      puts "entering at command mode again"
      @s.write("+++")
      puts "#{read_response}"
      r = write_at_cmd "AP0"
      puts "exiting api mode (AP = 0): #{r}"
      save!
      write_at_cmd "CN"   # exit command mode (this applies changes too)
    end
    
  end
  
  class XbeeListener < XbeeApi
    def initialize(opts={:no_setup => true})
      super(opts)
    end
  end # end class XbeeListener
  
end # end module Xbeer