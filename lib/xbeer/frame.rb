require 'xbeer/string'

module Xbeer

  class Frame
    
    def self.checksum(data)
      0xFF - (data.unpack("C*").inject(0) { |sum, byte| (sum + byte) & 0xFF })
    end
    
    attr_accessor :api_identifier, :cmd_data, :frame_id

    def initialize(api_identifier=0x00, cmd_data="")
       @cmd_data = cmd_data
       @api_identifier = api_identifier
    end

    def length 
      frame_data.length
    end

    def frame_data
      Array(@api_identifier).pack("C") + @cmd_data
    end

    def to_frame
      raise "Too much data (#{self.length} bytes) to fit into one frame!" if (self.length > 0xFFFF)
      "~" + [self.length].pack("n").xb_escape + frame_data.xb_escape + [Frame.checksum(frame_data)].pack("C")
    end
    
    
    
  end
  
end # end module Xbeer