#! /usr/bin/ruby

require 'optparse'
require 'open3'
require 'logger'

@log = Logger.new('/var/log/lxc-backup.log', 3, 1024000)
@log.level = Logger::INFO

config = {:name => nil, :remote => nil}

cli = OptionParser.new do |options|
  options.banner = "Usage: backup [options]"
  options.define '-n', '--name=CONTAINER_NAME', 'Specify a LXD container name to snapshot and backup'

  options.define '-r', '--remote=REMOTE', 'Specify a LXD remote, defaults to \'production\''

  options.define '-s', '--silent', 'Surpress output'

  options.define '-v', '--verbose', 'Enable debug mode'

  options.on('-h', '--help', 'Displays Help') do
    puts options
    exit
  end
end

cli.parse!(into: config)

exit if config[:name] == nil && config[:silent]

@log.level = Logger::DEBUG if config[:verbose]

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

  success = (result.exitstatus == 0)

  if !success
    if !fatal
      @log.info("Non-fatal error executing command '#{command}'")
      @log.info("#{stdout}") if stdout.strip != ""
      @log.info("#{result}")
      @log.info("#{stdeerr}") if stdeerr.strip != ""
    else
      @log.error("Error executing command '#{command}'")
      @log.error("#{stdout}") if stdout.strip != ""
      @log.error("#{result}")
      @log.error("#{stdeerr}") if stdeerr.strip != ""
      abort "Command failed: '#{command}'"
    end
  else
    @log.debug("Successfuly executed '#{command}'")
    @log.debug("#{stdout}") if stdout.strip != ""
    @log.debug("#{result}")
    @log.debug("#{stdeerr}") if stdeerr.strip != ""
  end
  success
end


# Title

puts "Copying LXD container #{CONTAINER_NAME} on #{LXC_REMOTE} to local.\n" unless config[:silent]
puts "With options: #{config}\n" unless config[:silent]
puts unless config[:silent]

@log.info("Backing up #{LXC_REMOTE}:#{CONTAINER_NAME}")

# Process
begin
  # Step 1: Delete any old backup
  system_p "lxc delete #{BACKUP_CONTAINER_NAME}", false

  # Step 2: Create a backup.
  system_p "lxc move #{CONTAINER_NAME} #{BACKUP_CONTAINER_NAME}", false

  # Step 3: Clean remote snapshot
  system_p "lxc delete #{LXC_REMOTE}:#{CONTAINER_NAME}/#{LXC_SNAPSHOT_NAME}", false

  # Step 4: Create remote snapshot
  unless system_p "lxc snapshot --stateful #{LXC_REMOTE}:#{CONTAINER_NAME} #{LXC_SNAPSHOT_NAME}", false
    system_p "lxc snapshot #{LXC_REMOTE}:#{CONTAINER_NAME} #{LXC_SNAPSHOT_NAME}"
  end

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

  @log.info("Backup #{LXC_REMOTE}:#{CONTAINER_NAME} Completed Successfully")

rescue Exception => e
  @log.error("Error backing up #{LXC_REMOTE}:#{CONTAINER_NAME}")
  @log.error "Uncaught #{e} exception while backing up. #{e.message}"
  @log.error "Stack Trace: #{e.backtrace.map {|l| "  #{l}\n"}.join}"
  raise e
end
