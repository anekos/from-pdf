#!/usr/bin/ruby
# vim: set fileencoding=utf-8 :

# require {{{
require 'fileutils'
require 'find'
require 'nokogiri'
require 'optparse'
require 'pathname'
require 'shellwords'
# }}}

# Option parser {{{
class Options
  attr_reader :source_filepath, :dest_directory, :directory, :base_path

  def initialize (argv)
    init
    parse(argv)
  end

  private
  def init
  end

  def parse (argv)
    OptionParser.new do |opt|
      # opt.on('-f FOO', '--foo FOO',  'Foo') {|v| @foo = v }
      opt.parse!(argv)
    end

    @source_filepath, @dest_directory = *argv.map {|it| Pathname(it) }
  end
end
# }}}

# App {{{
class App
  def initialize (options)
    @options = options
  end

  def start
    read_source
    write
  end

  private

  def write
    @options.dest_directory.mkpath
    @main_html = File.open(@options.dest_directory + 'index.html', 'w')

    @main_html.puts(<<EOT)
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title></title>
  <style>
    section p {
      margin: 0;
      padding: 0;
    }
    section.page-content {
      color: white;
      font-size: 19px;
    }
    .go-outline {
      display: block;
      margin-left: 48%;
    }
  </style>
</head>
<body>
  <div id="contents">
EOT

    outline_file = @base_path.sub_ext('-outline.html')
    if outline_file.file?
      outline = Nokogiri::HTML(File.read(outline_file))
      outline.search('h1').remove
      outline.css('a').each do
        |elem|
        if href = elem[:href] and n = href.match(/\d+\.html/)
          elem[:href] = "#page-#{n.to_s.to_i}"
        end
      end

      @main_html.puts(%Q[<section id="outline" class="outline">])
      @main_html.puts(outline.css('body > *').to_html)
      @main_html.puts('<hr />')
      @main_html.puts(%Q[</section>])
    end

    max_width = 0

    (1 ... @pages).each do
      |page|
      html = Nokogiri::HTML(File.read(page_filepath(page)))

      if width = html.css('div[style]').first[:style].match(/width:(\d+)px/)
        width = width[1].to_i
        max_width = width if max_width < width
      end

      img = image_filepath(page)
      FileUtils.cp(img, @options.dest_directory + img.basename)

      @main_html.puts(%Q[<label><a href="#page-#{page}">#{page}</a></label>]) if width
      @main_html.puts(%Q[<section id="page-#{page}" class="page-content">])
      html.css('body > *').each {|elem| @main_html.puts(elem.to_html) }
      @main_html.puts(%Q[</section>])
      @main_html.puts(%Q[<a href="#outline" style="margin-left: #{width}px">↑</a><br/>]) if width
    end

    @main_html.puts(<<EOT)
  </div>
</body>
</html>
EOT

  end

  def read_source
    @directory = @options.source_filepath.dirname
    @base_path = @directory + @options.source_filepath.basename.sub_ext('')

    n = 1
    while page = page_filepath(n).file?
      n += 1
    end
    @pages = n - 1
  end

  def page_filepath(n)
    @base_path.sub_ext("-#{n}.html")
  end

  def image_filepath(n)
    @base_path.sub_ext("%.3d.png" % n)
  end
end
# }}}


if __FILE__ == $0
  begin
    App.new(Options.new(ARGV)).start
  rescue Errno::EPIPE
    :ignore
  end
end
