#! /usr/local/rbenv/shims/ruby

require 'optparse'
require 'pry'

DEFAULT_SAMPLE_SIZE = 3
LINES_PER_CONTAINER = 3
LXC_CONTAINER_COPYING_TAG = 'copying'


COMMAND = %{lxc monitor | grep --line-buffered fs_progress | head -%d | sed --regexp-extended "s/.*?'(.*?)'/\\1/g"}

@sample_size = DEFAULT_SAMPLE_SIZE
@config = {:timeout => nil}

cli = OptionParser.new do |options|
  options.banner = "Usage: copy-satus.rb [options]"
  options.define '-t', '--timeout=SECONDS', 'Timeout after SECONDS'
  options.define '-p', '--poll', 'Poll until empty result, implies -t'

  options.on('-h', '--help', 'Displays Help') do
    puts options
    exit
  end
end

cli.parse!(into: @config)

def poll_lxc_list
  containers = `lxc list | grep "#{LXC_CONTAINER_COPYING_TAG}"`.split("\n").collect{|container| container.gsub /^\| (.*?)-copying.*?$/, '\1'}
  @containers = (@containers || []) + containers 
  container_count = @containers.count
  container_count = 1 if container_count == 0

  @sample_size = container_count * LINES_PER_CONTAINER
end

def generate_command
  unless @config[:timeout].nil?
    timeout = @config[:timeout].to_s.to_i

    "timeout -k #{timeout*2} #{timeout} #{COMMAND % @sample_size}"
  else
    COMMAND % sample_size
  end
end

def uniq input
  containers = @containers.collect{ |container| [container, 'Done.']}.to_h
  input = input.split("\n")
  input.each do |line|
    (container, text) = line.split(': ')
    container = container.gsub '-' + LXC_CONTAINER_COPYING_TAG, ''
    containers[container] = text
  end
  containers.collect{|k,v| k + ":\t" + v}.sort.join "\n"
end

def tableize input
  max_column_length = 0
  column_max_lengths = []
  lines = input.split("\n")
  columns = lines.first.count("\t") + 1

  lines.each do |line|
    line_columns = line.split("\t")
    line_columns.each_with_index do |text, i|
      previous_max_length = column_max_lengths[i] || 0
      column_max_lengths[i] = text.length if text.length > previous_max_length
    end
  end

  output = ''
  lines.each do |line|
    line_columns = line.split("\t")
    line_columns.each_with_index do |line_column, i|
      output += line_column.rjust(column_max_lengths[i] + ((i > 0) ? 1 : 0), ' ')
    end
    output += "\n"
  end
  output
end

# Have a default timeout of SAMPLE_SIZE if polling.
if @config[:poll] && @config[:timeout].nil?
  @config[:timeout] = (@sample_size * 2).ceil
end

# Include timeout in command.
command = generate_command

# Loop if polling, otherwise just call command.
if @config[:poll]
  last_result = nil
  result = nil

  while result != ""
    poll_lxc_list
    last_result = result
    result = uniq `#{generate_command}`

    if result != ""
      system 'clear'
      puts tableize result
    end
  end

  abort("No active copy detected.") if last_result.nil?
else
  puts uniq `#{command}`
end
