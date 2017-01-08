# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron


set :output, '/var/log/lxc-backup-cron.log'
every 1.days do
  command "/root/lxc-backup/backup.rb -n app1"
  command "/root/lxc-backup/backup.rb -n app2"
  command "/root/lxc-backup/backup.rb -n app3"
  command "/root/lxc-backup/backup.rb -n database"
  command "/root/lxc-backup/backup.rb -n loadbalancer"
  command "/root/lxc-backup/backup.rb -n web1"
end

# Learn more: http://github.com/javan/whenever
