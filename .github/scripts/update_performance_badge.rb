#!/usr/bin/env ruby
# 更新性能徽章脚本

require 'json'
require 'net/http'
require 'uri'

def load_performance_badge
  badge_path = 'tmp/performance_badge.json'
  return nil unless File.exist?(badge_path)

  JSON.parse(File.read(badge_path))
rescue JSON::ParserError
  nil
end

def update_shields_io_badge(badge_data)
  # 这里可以实现向shields.io更新徽章的逻辑
  # 或者将徽章数据保存到项目的badge目录
  puts "🏷️  性能徽章数据:"
  puts "  标签: #{badge_data['label']}"
  puts "  消息: #{badge_data['message']}"
  puts "  颜色: #{badge_data['color']}"

  # 保存徽章数据供其他工具使用
  FileUtils.mkdir_p('docs/badges')
  File.write('docs/badges/performance.json', JSON.pretty_generate(badge_data))
  puts "✅ 徽章数据已保存到 docs/badges/performance.json"
end

def generate_badge_svg(badge_data)
  color = badge_data['color']
  message = badge_data['message']
  label = badge_data['label']

  # 简单的SVG徽章生成
  svg = <<-SVG
<svg xmlns="http://www.w3.org/2000/svg" width="120" height="20">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="a">
    <rect width="120" height="20" rx="3" fill="#fff"/>
  </clipPath>
  <g clip-path="url(#a)">
    <path fill="#555" d="M0 0h55v20H0z"/>
    <path fill="#{color}" d="M55 0h65v20H55z"/>
    <path fill="url(#b)" d="M0 0h120v20H0z"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="27.5" y="15" fill="#010101" fill-opacity=".3">#{label}</text>
    <text x="27.5" y="14">#{label}</text>
    <text x="87.5" y="15" fill="#010101" fill-opacity=".3">#{message}</text>
    <text x="87.5" y="14">#{message}</text>
  </g>
</svg>
  SVG

  svg
end

def main
  badge_data = load_performance_badge

  unless badge_data
    puts "❌ 未找到性能徽章数据"
    exit 1
  end

  # 更新远程徽章服务（如果配置了）
  update_shields_io_badge(badge_data)

  # 生成SVG徽章
  svg_content = generate_badge_svg(badge_data)
  File.write('docs/badges/performance.svg', svg_content)
  puts "✅ SVG徽章已保存到 docs/badges/performance.svg"

  # 更新README中的徽章（如果存在）
  readme_path = 'README.md'
  if File.exist?(readme_path)
    readme_content = File.read(readme_path)
    badge_url = "docs/badges/performance.svg"

    if readme_content.include?('performance.svg')
      # 更新现有徽章
      readme_content.gsub!(/\[!\[Performance\]\(.*?performance\.svg\)\]/,
                             "[![Performance](#{badge_url})]")
      File.write(readme_path, readme_content)
      puts "✅ README.md 中的性能徽章已更新"
    else
      puts "ℹ️  README.md 中未找到性能徽章，可手动添加: [![Performance](#{badge_url})]"
    end
  end

  puts "🎉 性能徽章更新完成"
end

if __FILE__ == $0
  main
end