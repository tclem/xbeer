require 'xbeer/serial'
require 'pp'

module Xbeer

  class Xbee
  
    AT_COMMANDS = [
      {:VR => {:name => "firmware version", :desc => "(read only)"}},
      {:HV => {:name => "hardware version", :desc => "(read only)"}},
      {:CH => {:name => "channel         ", :desc => "(read/write, default 0xC) channel -> pan id -> dest address"}},
      {:ID => {:name => "pan id          ", :desc => "(read/write, default: 0x3332)"}},
      {:SL => {:name => "serial # lo     ", :desc => "(read only, set by manufacturer)"}},
      {:SH => {:name => "serial # hi     ", :desc => "(read only, set by manufacturer)"}},
      {:DL => {:name => "dest address lo ", :desc => "(read/write, default: 0x0, use 0xFFFF to broadcast)"}},
      {:DH => {:name => "dest address hi ", :desc => "(read/write, default: 0x0)"}},
      {:MY => {:name => "my 16bit address", :desc => "(read/write, default: 0x0, set to 0xFFFF to disable 16bit addressing)"}},
      ]
  
    def initialize(opts={})
      @s = Serial.new({:buffer_until => "\r"})
      @verbose = opts[:verbose] | true
      puts "connecting to xbee radio and entering AT mode..."
      @s.write("+++")
      puts "#{read_response}"
    end
  
    def show_all_commands
      for_all_commands do |c, n, d|
        puts "#{c} - #{n} (#{d})"
      end
    end
    
    def show_all_settings
      for_all_commands do |c, n, d|
        r = write_at_cmd c
        puts "#{n} (#{c}): 0x#{r} (#{r.to_i(16)} d) - #{d}"
      end
    end
  
    def show_neighbors
      puts "showing neighboring xbee modules...."
      
      r = write_at_cmd "ND"
      if (r.empty? || r.nil?)
        puts "no neighbors found" 
        return
      end

      n = []
      begin
        n = n << {:MY => r, 
                  :SH => read_response,
                  :SL => read_response,
                  :DB => -(read_response.hex),
                  :NI => read_response }
        read_response      # last <CR> that ends response
        r = read_response # either MY for next response or <CR> denoting end of all data
      end until (r.empty? || r.nil?)
      puts "found #{n.length} modules"
      pp n
      n
    end
    
    def save!
      write_at_cmd "WR"
    end
  
    # 
    def fw_rev
      write_at_cmd "VR"
    end
  
    # pass all other calls on to the serial port
    def method_missing(method, *args, &block)
      @s.send(method, *args)
    end
   
    private
  
    def write_at_cmd(cmd)
      @s.write("AT#{cmd}\r")
      read_response
    end
  
    def read_response
      begin
        r = @s.read!
        # puts "verbose: #{r}" if(@verbose && r != false)
        finished = true if r
      end until finished
      @s.clear_buffer!
      r.strip.chomp
    end
    
    def for_all_commands &block
      AT_COMMANDS.each do |command|
        command.each do |k, v|
          yield k.to_s, v[:name], v[:desc]
        end
      end
    end
  
  end # class Xbee

end # module Xbeer
