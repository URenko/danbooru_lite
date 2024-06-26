# frozen_string_literal: true

class Source::URL::Xiaohongshu < Source::URL
  attr_reader :user_id, :post_id, :full_image_url

  def self.match?(url)
    url.domain.in?(%w[xiaohongshu.com xhscdn.com xhslink.com])
  end

  def parse
    case [subdomain, domain, *path_segments]

    # http://sns-webpic-qc.xhscdn.com/202405050857/60985d4963cfb500a9b0838667eb3adc/1000g00828idf6nofk05g5ohki5uk137o8beqcv8!nd_dft_wgth_webp_3 (sample)
    in _, "xhscdn.com", /^\d{12}$/, /^\h{32}$/, /^([a-z0-9]+)!/
      image_id = basename.split("!").first
      @full_image_url = "https://ci.xiaohongshu.com/#{image_id}"

    # https://ci.xiaohongshu.com/bd871b0f-f9e7-54da-fd39-80b6af034dad?imageView2/2/w/100/h/100/q/75 (sample)
    # https://ci.xiaohongshu.com/bd871b0f-f9e7-54da-fd39-80b6af034dad (full)
    # https://ci.xiaohongshu.com/1000g00828idf6nofk05g5ohki5uk137o8beqcv8 (full)
    in "ci", "xiaohongshu.com", image_id
      @full_image_url = url.omit(:query).to_s

    # https://img.xiaohongshu.com/avatar/5b56be0014de415b2db830a6.jpg@160w_160h_92q_1e_1c_1x.jpg (profile picture, sample)
    # https://img.xiaohongshu.com/avatar/5b56be0014de415b2db830a6.jpg (full)
    in "img", "xiaohongshu.com", "avatar", _
      @full_image_url = "https://img.xiaohongshu.com/avatar/#{basename.split("@").first}"

    # https://www.xiaohongshu.com/explore/6421b331000000002702901f
    in _, "xiaohongshu.com", "explore", post_id
      @post_id = post_id

    # https://www.xiaohongshu.com/discovery/item/65880524000000000700a643
    in _, "xiaohongshu.com", "discovery", "item", post_id
      @post_id = post_id

    # https://www.xiaohongshu.com/user/profile/6234917d0000000010008cf8/6421b331000000002702901f
    in _, "xiaohongshu.com", "user", "profile", user_id, post_id
      @user_id = user_id
      @post_id = post_id

    # https://www.xiaohongshu.com/user/profile/6234917d0000000010008cf8
    in _, "xiaohongshu.com", "user", "profile", user_id
      @user_id = user_id

    # https://sns-avatar-qc.xhscdn.com/avatar/1040g2jo30s5tg4ugig605ohki5uk137o34ug2fo (profile picture)
    # https://picasso-static.xiaohongshu.com/fe-platform/81cedd016ad9d8bef38b2cd0c1e725454df53598.png (emoji)
    # http://xhslink.com/WNd9gI
    else
      nil
    end
  end

  def image_url?
    host.in?(%w[ci.xiaohongshu.com img.xiaohongshu.com]) || domain == "xhscdn.com"
  end

  def page_url
    if user_id.present? && post_id.present?
      "https://www.xiaohongshu.com/user/profile/#{user_id}/#{post_id}"
    elsif post_id.present?
      "https://www.xiaohongshu.com/explore/#{post_id}"
    end
  end

  def profile_url
    "https://www.xiaohongshu.com/user/profile/#{user_id}" if user_id.present?
  end
end
