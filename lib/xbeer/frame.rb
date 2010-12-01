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

  class ReceivePacket < ReceivedFrame
    attr_accessor :frame_id, :src_addr, :signal_strength, :received_message
    attr_reader :signal_strength_db
    
    def cmd_data=(data_string)
      src_high, src_low, self.signal_strength, opts, self.received_message = data_string.unpack("NNCCa*")
      self.src_addr = (src_high << 32) + src_low
      @signal_strength_db = "-#{@signal_strength} dB"
    end
  end
  
  class SafeTraxxPacket < ReceivedFrame
    
    def self.create(frame_data)
      case frame_data[11]
      when 1 : SafeTraxxGpsPacket.new(frame_data)
      when 2 : SafeTraxxDebugPacket.new(frame_data)
      else SafeTraxxPacket.new(frame_data)
      end
    end
    
    attr_accessor :frame_id, :src_addr, :signal_strength, :opts, :type, :inner_packet
    attr_reader :signal_strength_db
    
    def packet_types
      [ [1, :Gps_Packet], [2, :Debug_Packet], ]
    end
    
    def type_desc
      packet_types.assoc(@type)
    end
    
    def cmd_data=(data_string)
      src_high, src_low, @signal_strength, @opts = data_string.unpack("NNCC")
      self.src_addr = (src_high << 32) + src_low
      @signal_strength_db = "-#{@signal_strength} dB"
      @type = data_string[10]
      self.inner_packet = data_string[11..-1]
    end
  end
  
  class SafeTraxxDebugPacket < SafeTraxxPacket
    attr_accessor :msg
    
    def inner_packet=(data_string)
      @msg = data_string.unpack("a*")
    end
  end
  
  class SafeTraxxGpsPacket < SafeTraxxPacket
    attr_accessor :lat, :long, :summary, :course, :speed
    
    def inner_packet=(data_string)
      u_lat, u_long, raw_course, raw_speed = data_string.unpack("NNNN")
      
      @lat = to_signed(u_lat) * 10**-5    # degrees
      @long = to_signed(u_long) * 10**-5  # degrees
      @course = raw_course * 10**-2 # degrees
      @speed = raw_speed * 10**-2   # knots
      @summary = "Position in deg: (#{@lat}, #{@long}), Course in deg: #{@course}, Speed in knots: #{@speed}"
    end
    
    private
    def to_signed(n)
      length = 32
      mid = 2**(length-1)
      max_unsigned = 2**length
      (n>=mid) ? n - max_unsigned : n
    end
  end
  
  # class GpsReceivePacket < ReceivePacket
  #   attr_accessor :lat, :long, :summary, :course, :speed
  #   
  #   def cmd_data=(data_string)
  #     src_high, src_low, 
  #     @signal_strength, opts, u_lat, u_long, 
  #     raw_course, raw_speed = data_string.unpack("NNCCNNNN")
  #     
  #     @src_addr = (src_high << 32) + src_low
  #     @signal_strength_db = "-#{@signal_strength} dB"
  #     @lat = to_signed(u_lat) * 10**-5    # degrees
  #     @long = to_signed(u_long) * 10**-5  # degrees
  #     @course = raw_course * 10**-2 # degrees
  #     @speed = raw_speed * 10**-2   # knots
  #     @summary = "Position in deg: (#{@lat}, #{@long}), Course in deg: #{@course}, Speed in knots: #{@speed}"
  #   end
  #   
  #   private
  #   def to_signed(n)
  #     length = 32
  #     mid = 2**(length-1)
  #     max_unsigned = 2**length
  #     (n>=mid) ? n - max_unsigned : n
  #   end
  # end

  class TransmitStatusResponse < ReceivedFrame
    attr_accessor :frame_id, :status
    
    def command_statuses
      [:OK, :NO_ACK, :CCA_FAILURE, :PURGED]
    end
    
    def cmd_data=(data_string)
      self.frame_id, status_byte = data_string.unpack("CC")
      self.status = case status_byte
      when 0..3 : command_statuses[status_byte]
      else raise "Transmit Status Response frame appears to include an invalid status: 0x%x" % status_byte
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