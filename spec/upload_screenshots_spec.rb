require 'spec_helper'
require 'pry'
require 'fakefs/spec_helpers'
require 'deliver'
require 'stubs/upload_stubbing'

describe Deliver::UploadScreenshots do
  include FakeFS::SpecHelpers

  before :each do
    @root = '/tmp/screenshots/'
    FileUtils.mkdir_p(@root)

    FileUtils.mkdir_p('/Users/denis/')
    File.open('/Users/denis/.pry_history', 'w')

    (1..5).each do |i|
      file_path = File.join(@root, "scr_#{i}.jpg")
      File.open(file_path, 'w') { |file| file.write("#{i}") }
    end
  end

  def mock_local_upload(sequence)
    @order = 0
    to_upload = sequence.map do |i|
      file_path = File.join(@root, "scr_#{i}.jpg")
      file = Screenshot.new(file_path, 'en-US')
      md5 = Spaceship::Utilities.get_source_md5(file_path)
      file.original_file_name = "ftl_#{md5}_scr_#{i}.jpg"
      file.sort_order = @order
      @order += 1
      file
    end
    to_upload
  end

  let(:options) { { app: FakeApp.new } }

  context "Deleting screenshots from ITC" do
    it "should delete screenshot from ITC when order had been changed" do
      # 1st and 2nd changed places. Expecting deletion of both
      expect do
        Deliver::UploadScreenshots.new.upload(options, mock_local_upload([2, 1, 3, 4]))
      end.to output(/Deleting 1 for device iphone4\nDeleting 2 for device iphone4/).to_stdout
    end

    it "should delete screenshot from ITC when file had been changed" do
       # 1st changed. Expecting deletion of first
      expect do
        Deliver::UploadScreenshots.new.upload(options, mock_local_upload([5, 2, 3, 4]))
      end.to output(/Deleting 1 for device iphone4/).to_stdout
    end

    it "should delete screenshot from ITC when there's no md5 in filename" do
      # 5th don't have md5 in file name. Expecting deletion
      to_upload = mock_local_upload([1, 2, 3, 4, 5])

      file_path = "spec/assets/screenshot_iphone4_640x1136_5.jpg"
      file = Screenshot.new(file_path, 'en-US')
      file.original_file_name = "screenshot_iphone4_640x1136_5.jpg"
      file.sort_order = 5
      options[:app].edit_version.screenshots['en-US'] << file
      expect do
        Deliver::UploadScreenshots.new.upload(options, to_upload)
      end.to output(/Deleting 5 for device iphone4/).to_stdout
    end
  end

  context "Uploading screenshots to ITC" do

    it "should skip screenshot upload when screenshot is already uploaded on ITC with the same order" do
      #nothing's changed upload_screenshot! won't be called at all
      expect do
        Deliver::UploadScreenshots.new.upload(options, mock_local_upload([1, 2, 3, 4]))
      end.to output('').to_stdout
    end
  end
end
