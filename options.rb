#! /usr/local/rbenv/shims/ruby

require 'optparse'
require 'pry'

config = {:name => nil, :remote => nil}

cli = OptionParser.new do |options|
  options.banner = "Usage: backup [optionss]"
  options.define '-n', '--name=CONTAINER_NAME'

  options.define '-r', '--remote=LXD_REMOTE'

  options.on('-h', '--help', 'Displays Help') do
    puts options
    exit
  end
end

cli.parse!(into: config)

binding.pry