#! /usr/local/rbenv/shims/ruby

require 'optparse'
require 'open3'
require 'logger'
require 'pry'

log = Logger.new('lxc-backup.log', 3, 1024000)
log.level = Logger::INFO

config = {:name => nil, :remote => nil}

cli = OptionParser.new do |options|
  options.banner = "Usage: backup [options]"
  options.define '-n', '--name=CONTAINER_NAME', 'Specify a LXD container name to snapshot and backup'

  options.define '-r', '--remote=REMOTE', 'Specify a LXD remote, defaults to production'

  options.define '-s', '--silent', 'surpress output'

  options.on('-h', '--help', 'Displays Help') do
    puts options
    exit
  end
end

cli.parse!(into: config)

exit if config[:name] == nil && config[:silent]

if config[:name] == nil
  print 'Enter LXC Container Name: '
  config[:name] = gets.chomp
end
config[:remote] ||= 'production'

# Config
CONTAINER_NAME = config[:name]
LXC_REMOTE = config[:remote]

LXC_SNAPSHOT_NAME = 'backup'
BACKUP_CONTAINER_NAME = "#{CONTAINER_NAME}-backup"
TEMP_CONTAINER_NAME = "#{CONTAINER_NAME}-copying"


# Helper functions

def system_p command, fatal=true

  stdout, stdeerr, result = Open3.capture3(command)

  if !result
    if !fatal
      logger.warn("Error executing command #{command}")
      logger.warn("#{stdout}")
      logger.warn("#{stdeerr}")
    else
      logger.error("Error executing command #{command}")
      logger.error("#{stdout}")
      logger.error("#{stdeerr}")
      abort "Command failed"
    end
  end
  result
end


# Title

puts "Copying LXD container #{CONTAINER_NAME} on #{LXC_REMOTE} to local.\n" unless config[:silent]
puts unless config[:silent]

logger.info("Backing up #{LXC_REMOTE}:#{CONTAINER_NAME}")

# Process
begin
  # Step 1: Delete any old backup
  system_p "lxc delete #{BACKUP_CONTAINER_NAME}", false

  # Step 2: Create a backup.
  system_p "lxc move #{CONTAINER_NAME} #{BACKUP_CONTAINER_NAME}", false

  # Step 3: Clean remote snapshot
  system_p "lxc delete #{LXC_REMOTE}:#{CONTAINER_NAME}/#{LXC_SNAPSHOT_NAME}", false

  # Step 4: Create remote snapshot
  system_p "lxc snapshot --stateful #{LXC_REMOTE}:#{CONTAINER_NAME} #{LXC_SNAPSHOT_NAME}"

  # Step 5: Delete any local temp snapshot
  system_p "lxc delete #{TEMP_CONTAINER_NAME}", false

  # Step 6: Copy remote snapshot to local temp snapshot
  unless system_p("lxc copy #{LXC_REMOTE}:#{CONTAINER_NAME}/#{LXC_SNAPSHOT_NAME} #{TEMP_CONTAINER_NAME}", false)
    system_p "lxc move #{BACKUP_CONTAINER_NAME} #{CONTAINER_NAME}"
  end
  
  # Step 7: Move local temp snapshot into place
  system_p "lxc move #{TEMP_CONTAINER_NAME} #{CONTAINER_NAME}"

  # Step 8: Delete backup snapshot
  system_p "lxc delete #{BACKUP_CONTAINER_NAME}", false

  logger.info('Completed Successfully')

rescue Exception => e
  logger.error("Error backing up #{LXC_REMOTE}:#{CONTAINER_NAME}")
  logger.error "Uncaught #{e} exception while backing up. #{e.message}"
  logger.error "Stack Trace: #{e.backtrace.map {|l| "  #{l}\n"}.join}"
  raise e
end
