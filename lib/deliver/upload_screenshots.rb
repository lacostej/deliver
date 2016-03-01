module Deliver
  # upload screenshots to iTunes Connect
  class UploadScreenshots
    def upload(options, screenshots)
      return if options[:skip_screenshots]

      app = options[:app]

      v = app.edit_version
      UI.user_error!("Could not find a version to edit for app '#{app.name}'") unless v

      UI.message("Removing previously uploaded screenshots...")
      # First, clear all previously uploaded screenshots, but only where we have new ones

      # md5's of uploaded screenshots
      checksums_local = {}
      # md5's of ITC screenshots
      checksums_remote = {}

      screenshots.each do |screenshot|
        # checksum of uploaded screenshot
        md5 = Digest::MD5.hexdigest(File.read(screenshot.path))
        checksums_local[screenshot.language] ||= []
        checksums_local[screenshot.language].push(md5)
      end

      v.screenshots.each do |lang, screenshots_for_lang|
        screenshots_for_lang.each do |current|
          checksum = current.original_file_name.split('_')
          checksum = checksum[1]

          # store remote checksum. We will need it later to determine if we have to upload screenshot
          checksums_remote[current.language] ||= []
          checksums_remote[current.language].push(checksum)

          # Remove from ITC non existing locally screenshots
          if !checksums_local[current.language].include?(checksum)
            UI.message("Deleting screenshot #{current.original_file_name} for language #{current.language}")
            v.upload_screenshot!(nil, current.sort_order, current.language, current.device_type)
          end
        end
      end

      # This part is not working yet...

      UI.message("Starting with the upload of screenshots...")

      # Now, fill in the new ones
      indized = {} # per language and device type

      screenshots_per_language = screenshots.group_by(&:language)
      screenshots_per_language.each do |language, screenshots_for_language|
        UI.message("Uploading #{screenshots_for_language.length} screenshots for language #{language}")
        screenshots_for_language.each do |screenshot|
          indized[screenshot.language] ||= {}
          indized[screenshot.language][screenshot.device_type] ||= 0
          indized[screenshot.language][screenshot.device_type] += 1 # we actually start with 1... wtf iTC

          index = indized[screenshot.language][screenshot.device_type]

          if index > 5
            UI.error("Too many screenshots found for device '#{screenshot.device_type}' in '#{screenshot.language}'")
            next
          end

          # md5 of uploaded file
          md5 = Digest::MD5.hexdigest(File.read(screenshot.path))

          if checksums_remote[screenshot.language].include?(md5)
            UI.message("Screenshot #{screenshot.path} already uploaded. Skipping")
          else
            UI.message("Uploading '#{screenshot.path}'...")
            v.upload_screenshot!(screenshot.path,
                                 index,
                                 screenshot.language,
                                 screenshot.device_type)
          end
        end
        # ideally we should only save once, but itunes server can't cope it seems
        # so we save per language. See issue #349
        UI.message("Saving changes")
        v.save!
      end
      UI.success("Successfully uploaded screenshots to iTunes Connect")
    end

    def collect_screenshots(options)
      return [] if options[:skip_screenshots]
      return collect_screenshots_for_languages(options[:screenshots_path])
    end

    def collect_screenshots_for_languages(path)
      screenshots = []
      extensions = '{png,jpg,jpeg}'

      Loader.language_folders(path).each do |lng_folder|
        language = File.basename(lng_folder)

        # Check to see if we need to traverse multiple platforms or just a single platform
        if language == Loader::APPLE_TV_DIR_NAME
          screenshots.concat(collect_screenshots_for_languages(File.join(path, language)))
          next
        end

        files = Dir.glob(File.join(lng_folder, "*.#{extensions}"), File::FNM_CASEFOLD)
        next if files.count == 0

        prefer_framed = Dir.glob(File.join(lng_folder, "*_framed.#{extensions}"), File::FNM_CASEFOLD).count > 0

        language = File.basename(lng_folder)
        files.each do |file_path|
          if file_path.downcase.include?("_framed.")
            # That's cool
          else
            if file_path.downcase.include?("watch")
              # Watch doesn't support frames (yet)
            else
              # That might not be cool... if that screenshot is not framed but we only want framed
              next if prefer_framed
            end
          end

          screenshots << AppScreenshot.new(file_path, language)
        end
      end

      return screenshots
    end
  end
end
