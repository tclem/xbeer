require 'xbeer/xbee'
require 'xbeer/frame'
require 'pp'

module Xbeer
  
  class XbeeApi < Xbee
    
    def initialize(opts={})
      super(opts)
      # r = write_at_cmd "AP2"
      # puts "ensuring api mode (AP = 2): #{r}"
      # save!
      # write_at_cmd "CN"   # exit command mode (this applies changes too)
      @frame_id = 0x52
    end
    
    def read_api
      stray_bytes = []
      until (start_delimiter = source_io.readchar) == 0x7e
        puts "Stray byte 0x%x" % start_delimiter
        stray_bytes << start_delimiter
      end
      puts "Got some stray bytes for ya: #{stray_bytes.map {|b| "0x%x" % b} .join(", ")}" unless stray_bytes.empty?
      header = source_io.read(3).xb_unescape
      puts "Read header: #{header.unpack("C*").join(", ")}"
      frame_remaining = frame_length = api_identifier = cmd_data = ""
      if header.length == 3
        frame_length, api_identifier = header.unpack("nC")
      else
        frame_length, api_identifier = header.unpack("n").first, source_io.readchar
      end
      cmd_data_intended_length = frame_length - 1
      while ((unescaped_length = cmd_data.xb_unescape.length) < cmd_data_intended_length)
        cmd_data += source_io.read(cmd_data_intended_length - unescaped_length)
      end
      data = api_identifier.chr + cmd_data.xb_unescape
      sent_checksum = source_io.getc
      unless sent_checksum == Frame.checksum(data)
        raise "Bad checksum - data discarded"
      end
      pp data
      data
    end
    
    def send_at_cmd(cmd)
      f = Frame.new(0x08, [@frame_id, cmd].pack("ca*"))
      pp f
      pp f.frame_data.unpack("H*")
      pp f.to_frame.unpack("H*")
    end
    
  end
  
end # end module Xbeer