require 'xbeer/string'

module Xbeer
  
  class Frame
    attr_accessor :api_identifier, :cmd_data, :frame_id
    
    def self.checksum(data)
      0xFF - (data.unpack("C*").inject(0) { |sum, byte| (sum + byte) & 0xFF })
    end

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

  class ReceivedFrame < Frame
    def initialize(frame_data)
      self.api_identifier = frame_data[0]
      self.cmd_data = frame_data[1..-1]
    end
  end  

  class TransmitStatusResponse < ReceivedFrame
    attr_accessor :frame_id, :status
    
    def command_statuses
      [:OK, :NO_ACK, :CCA_FAILURE, :PURGED]
    end
    
    def cmd_data=(data_string)
      self.frame_id, status_byte = data_string.unpack("CC")
      self.status = case status_byte
      when 0..3 : command_statuses[status_byte]
      else raise "AT Command Response frame appears to include an invalid status: 0x%x" % status_byte
      end
    end
    
  end

  class ATCommandResponse < ReceivedFrame
    attr_accessor :frame_id, :at_command, :status, :retrieved_value

    def initialize(data = nil)
      super(data) && (yield self if block_given?)
    end

    def command_statuses
      [:OK, :ERROR, :Invalid_Command, :Invalid_Parameter]
    end

    def cmd_data=(data_string)
      self.frame_id, self.at_command, status_byte, self.retrieved_value = data_string.unpack("Ca2Ca*")
      self.status = case status_byte
      when 0..3 : command_statuses[status_byte]
      else raise "AT Command Response frame appears to include an invalid status: 0x%x" % status_byte
      end
      #actually assign and move along
      @cmd_data = data_string
    end
    
  end
  
end # end module Xbeer