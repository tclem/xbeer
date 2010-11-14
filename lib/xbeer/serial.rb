require 'rubygems'
require 'serialport'

module Xbeer

  class Serial
    attr_reader :buffer, :port
  
    def self.list
      Dir.new("/dev").entries.select{|e| e =~ /tty\./}
    end
  
    def initialize(opts={})
      Dir.chdir("/dev")
      usb = Dir.glob("tty.usbserial*")
    
      @baud_rate = opts[:baud_rate] || 9600
      @data_bits = 8
      @stop_bits = 1
      @parity = SerialPort::NONE
      @port_str = opts[:port] || "/dev/#{usb}"
      raise "Error: Did not find a valid usb device attached!" if(@port_str == "/dev/") 
      puts "using #{usb} baud_rate: #{@baud_rate}"
      @port = SerialPort.new(@port_str, @baud_rate, @data_bits, @stop_bits, @parity)
      @port.read_timeout = opts[:read_timeout] || 200
      @buffer = "" # ? v. bytes
      @buffer_until = convert_to_byte( opts[:buffer_until]) if opts[:buffer_until]
    end
  
    def read! &block
      raise "buffer_until is not set, this will run forever!" unless @buffer_until
      s = @port.getc
      @buffer << s.chr if s
      if (s == @buffer_until)
        if block_given?
          yield
        else
          @buffer
        end
      else
        false
      end
    end
  
    def buffer_until=(s)
      @buffer_until = convert_to_byte(s)
    end
  
    def buffer_until
      @buffer_until.chr
    end
  
    def clear_buffer!
      @buffer = "" # ? v. bytes
    end
  
    def convert_to_byte(s)
      raise ArgumentError, "can only use a string or integer to buffer" unless s.is_a?(String) || s.is_a?(Integer)
      if s.is_a? String
        s[0]
      else
        s
      end
    end
  
    def method_missing(method, *args, &block)
      @port.send(method, *args)
    end
  end

end # module Xbeer