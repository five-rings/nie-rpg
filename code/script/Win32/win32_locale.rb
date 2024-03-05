=begin
=end
module Win32::Locale
  begin
    GetUserDefaultLocaleName = Win32API.new('kernel32', 'GetUserDefaultLocaleName', ['P','L'], 'L')
    LOCALE_NAME_MAX_LENGTH = 85
  rescue
    GetUserDefaultLocaleName = nil
    begin
      GetLocaleInfo = Win32API.new('kernel32', 'GetLocaleInfo', ['L','L', 'P', 'L'], 'L')
      LOCALE_SIOS_MAX_LENGTH = 9
      LOCALE_USER_DEFAULT = 0x400
      LOCALE_SISO639LANGNAME = 0x59
      LOCALE_SISO3166CTRYNAME = 0x5a
    rescue
      GetLocaleInfo = nil
    end
  end

class << self

  def getUserDefaultLocaleName(buffer = nil)
    return getLocaleInfo(buffer) unless GetUserDefaultLocaleName

    buffer ||= " " * LOCALE_NAME_MAX_LENGTH
    buffer.encode!('UTF-16LE')
    GetUserDefaultLocaleName.call(buffer, buffer.size)
    buffer.encode!('UTF-8')
    buffer.rstrip!
    buffer
  end

  def getLocaleInfo(buffer = nil)
    return "" unless GetLocaleInfo

    buffer ||= " " * LOCALE_SIOS_MAX_LENGTH
    name = ""

    GetLocaleInfo.call(LOCALE_USER_DEFAULT, LOCALE_SISO639LANGNAME, buffer, buffer.size)
    name << buffer
    name.rstrip!

    GetLocaleInfo.call(LOCALE_USER_DEFAULT, LOCALE_SISO3166CTRYNAME, buffer, buffer.size)
    name << "-" << buffer
    name.rstrip!

    name
  end

end
end
