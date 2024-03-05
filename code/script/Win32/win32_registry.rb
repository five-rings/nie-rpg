=begin
  レジストリ操作用のWrapper
=end
class Win32::Registry
  # RegOpenKeyEx = Win32API.new('advapi32', 'RegOpenKeyEx', ['L','P','L','L','P'], 'L')
  RegCreateKeyEx = Win32API.new('advapi32', 'RegCreateKeyEx', ['L','P','L','P','L','L','P','P','P'], 'L')
  RegCloseKey = Win32API.new('advapi32', 'RegCloseKey', ['L'], 'L')
  RegQueryValueEx = Win32API.new('advapi32', 'RegQueryValueEx', ['L','P','L','P','P','P'], 'L')
  RegSetValueEx = Win32API.new('advapi32', 'RegSetValueEx', ['L','P','L','L','P','L'], 'L')

  module Constants
    HKEY_CURRENT_USER = 0x80000001

    KEY_QUERY_VALUE = 0x0001
    KEY_SET_VALUE = 0x0002
    KEY_CREATE_SUB_KEY = 0x0004

    ERROR_SUCCESS = 0

    REG_OPTION_NON_VOLATILE = 0

    REG_NONE = 0
    REG_SZ = 1
    REG_EXPAND_SZ = 2
    REG_BINARY = 3
    REG_DWORD = 4
    REG_DWORD_LITTLE_ENDIAN = 4
    REG_DWORD_BIG_ENDIAN = 5
    REG_LINK = 6
    REG_MULTI_SZ = 7
    REG_RESOURCE_LIST = 8
    REG_FULL_RESOURCE_DESCRIPTOR = 9
    REG_RESOURCE_REQUIREMENTS_LIST = 10
    REG_QWORD = 11
    REG_QWORD_LITTLE_ENDIAN = 11
  end
  include Constants
  PATH = "Software\\Enterbrain\\RGSS3"

  def initialize
    buffer = [0].pack('L')
    # ret = RegOpenKeyEx.call(HKEY_CURRENT_USER, PATH, 0, KEY_QUERY_VALUE | KEY_SET_VALUE, buffer)
    ret = RegCreateKeyEx.call(HKEY_CURRENT_USER, PATH, 0, 0, REG_OPTION_NON_VOLATILE, KEY_CREATE_SUB_KEY | KEY_SET_VALUE | KEY_QUERY_VALUE, 0, buffer, 0)
    case ret
    when ERROR_SUCCESS
      @handle = buffer.unpack('L')[0]
    else 
      ITEFU_DEBUG_OUTPUT_ERROR "Failed to RegOpenKeyEx (error code: #{ret})"
    end

    if open? && block_given?
      yield(self)
      close
    end
  end

  def self.open
    instance = self.new
    if instance.open? && block_given?
      ret = yield(instance)
      instance.close
      ret
    end
  end

  def open?
    @handle.nil?.!
  end

  def close
    return unless open?
    ret = RegCloseKey.call(@handle)
    case ret
    when ERROR_SUCCESS
    else
      ITEFU_DEBUG_OUTPUT_ERROR "Failed to RegCloseKey (error code: #{ret})"
    end
    @handle = nil
  end

  def getValue(key)
    ITEFU_DEBUG_ASSERT(open?, "RegOpenKeyEx should be successfully called before calling getValue(#{key})")
    type = [0].pack('L')
    buffer = [0].pack('L')
    size = [buffer.size].pack('L')
    ret = RegQueryValueEx.call(@handle, key.to_s, 0, type, buffer, size)
    if ret != ERROR_SUCCESS
      ITEFU_DEBUG_OUTPUT_ERROR "Failed to RegQueryValueEx(#{key}) (error code: #{ret})"
    end

    type = type.unpack('L')[0]
    size = size.unpack('L')[0]

    case type
    when REG_DWORD
      buffer.unpack('L')[0]
    else
      ITEFU_DEBUG_OUTPUT_ERROR "Not Supported: type(#{type}) in key(#{key}) from RegQueryValueEx"
    end
  end

  def setValue(key, value)
    ITEFU_DEBUG_ASSERT(open?, "RegOpenKeyEx should be successfully called before calling setValue(#{key})")

    case value
    when Fixnum
      buffer = [value].pack('L')
      ret = RegSetValueEx.call(@handle, key.to_s, 0, REG_DWORD, buffer, buffer.size)
    else
      ITEFU_DEBUG_OUTPUT_ERROR "Not Supported: value(#{value.class}) should be Fixnum for RegSetValueEx"
      ITEFU_DEBUG_OUTPUT_ERROR " value: #{value.inspect}"

      return
    end

    case ret
    when ERROR_SUCCESS
    else
      ITEFU_DEBUG_OUTPUT_ERROR "Failed to RegSetValueEx(#{key}) (error code: #{ret})"
    end
  end

end

