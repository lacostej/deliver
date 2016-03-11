# Our fake application
class FakeApp
  def edit_version
    @ev ||= EditVersion.new
  end
end

# Screenshot class shared between ITC Sceenshot and Deliver Screenshot
class Screenshot

  def initialize(path, language, screen_size = nil)
    self.path = path
    self.device_type = "iphone4"
    self.language = language
    self.screen_size = 'iOS-4-in'
  end
  attr_accessor :sort_order, :original_file_name, :path, :language, :device_type, :screen_size

  @original_file_name = ''
  @sort_order = 0
end

# Fake EditEversion with necessary methods stubbed
class EditVersion

  def screenshots
    @ret ||= {}
    return @ret unless @ret.empty?
    @ret['en-US'] ||= []
    root = '/tmp/screenshots/'
    (1..4).each do |i|
      file_path = File.join(root, "scr_#{i}.jpg")
      file = Screenshot.new(file_path, 'en-US')
      md5 = Spaceship::Utilities.get_source_md5(file_path)
      file.original_file_name = "ftl_#{md5}_scr_#{i}.jpg"
      file.sort_order = i
      @ret['en-US'] << file
    end
    @ret
  end

  # we don't have to really upload. It's enoguth to know if we are uploading or deleting
  def upload_screenshot!(path, order, lang, device)
    if path
      puts "Uploading '#{path}' for device #{device}"
    else
      puts "Deleting #{order} for device #{device}"
    end
  end

  def save!
  end
end