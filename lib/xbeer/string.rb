class String
  def xb_escape
    self.gsub(/[\176\175\021\023]/) { |c| [0x7D, c[0] ^ 0x20].pack("CC")}
  end
  def xb_unescape
    self.gsub(/\175./) { |ec| [ec.unpack("CC").last ^ 0x20].pack("C")}
  end
end