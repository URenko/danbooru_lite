# frozen_string_literal: true

require 'pycall'

# A MediaFile for a JPEG, PNG, or GIF file. Uses libvips for resizing images.
#
# @see https://github.com/libvips/ruby-vips
# @see https://libvips.github.io/libvips/API/current
class MediaFile::Image < MediaFile
  delegate :thumbnail_image, to: :image

  def close
    super
    @preview_frame&.close unless @preview_frame == self
    @preview_frame = nil
    @image&.close
    @image = nil
  end

  def dimensions
    [image.width, image.height]
  rescue
    [metadata.width, metadata.height]
  end

  def is_supported?
    case file_ext
    when :avif
      # XXX Mirrored AVIFs should be unsupported too, but we currently can't detect the mirrored flag using exiftool or ffprobe.
      !metadata.is_rotated? && !metadata.is_cropped? && !metadata.is_grid_image? && !metadata.is_animated_avif?
    when :webp
      !is_animated?
    else
      true
    end
  end

  def is_corrupt?
    error.present?
  end

  def error
    image = open_image(fail: true)
    image.verify
    image.close
    nil
  end

  def metadata
    super.merge({ "Vips:Error" => error }.compact_blank)
  end

  def duration
    return nil if !is_animated?

    # XXX ffmpeg 6.1 calculates duration incorrectly for some gif and webp files.
    case file_ext
    when :gif, :webp
      vips_duration
    else
      ffmpeg_duration
    end
  end

  def frame_count
    case file_ext
    when :gif, :webp
      n_pages
    when :png
      exif_metadata.fetch("PNG:AnimationFrames", 1)
    when :avif
      video.frame_count
    else
      nil
    end
  end

  # @return [Integer, nil] The duration of the animation as calculated by libvips, or possibly nil if the file
  #   isn't animated or is corrupt. Note that libvips and ffmpeg may disagree on the duration.
  def vips_duration
    # XXX Browsers typically raise the frame time to 0.1s if it's less than or equal to 0.01s.
    image.get("delay").map { |delay| delay <= 10 ? 100 : delay }.sum / 1000.0
  end

  # @return [Integer, nil] The duration of the animation as calculated by ffmpeg, or possibly nil if the file
  #   isn't animated or is corrupt. Note that libvips and ffmpeg may disagree on the duration.
  def ffmpeg_duration
    video.duration
  end

  # @return [Integer, nil] The frame count for gif and webp images, or possibly nil if the file doesn't have a frame count or is corrupt.
  def n_pages
    image.get("n-pages")
  end

  def frame_rate
    return nil if !is_animated? || frame_count.nil? || duration.nil? || duration == 0
    frame_count / duration
  end

  def channels
    image.bands
  end

  def colorspace
    image.mode
  end

  def resize!(max_width, max_height, format: :jpeg, quality: 85, **options)
    # @see https://www.libvips.org/API/current/Using-vipsthumbnail.md.html
    # @see https://www.libvips.org/API/current/libvips-resample.html#vips-thumbnail
    image.convert("RGB").thumbnail(PyCall.tuple([max_width, max_height]))
    output_file = Danbooru::Tempfile.new(["danbooru-image-preview-#{md5}-", ".#{format.to_s}"])
    image.save(output_file, format)
    image.close
    MediaFile::Image.new(output_file)
  end

  def preview!(max_width, max_height, **options)
    w, h = MediaFile.scale_dimensions(width, height, max_width, max_height)
    MediaFile::Image.new(preview_frame.file).resize!(w, h, **options)
  end

  def is_animated?
    frame_count.to_i > 1
  end

  def is_animated_gif?
    file_ext == :gif && is_animated?
  end

  def is_animated_png?
    file_ext == :png && is_animated?
  end

  def is_animated_webp?
    file_ext == :webp && is_animated?
  end

  def is_animated_avif?
    file_ext == :avif && is_animated?
  end

  # Return true if the image has an embedded ICC color profile.
  def has_embedded_profile?
    image.get_typeof("icc-profile-data") != 0
  end

  def pixel_hash
    md5
  end

  private

  # @return [Vips::Image] the Vips image object for the file
  def image
    @image ||= open_image(fail: false)
  end

  def open_image(**options)
    pillow = PyCall.import_module("PIL.Image")
    pillow.open(file.path)
  end

  def video
    FFmpeg.new(self)
  end

  def preview_frame
    @preview_frame ||= begin
      if is_animated?
        video.smart_video_preview || self
      else
        self
      end
    end
  end

  memoize :video, :dimensions, :error, :metadata, :is_corrupt?, :is_animated_gif?, :is_animated_png?
end
