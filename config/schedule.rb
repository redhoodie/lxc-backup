# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron


set :output, '/var/log/lxc-backup-cron.log'

every 1.days, :at => '1:00 am' do
  command "/root/lxc-backup/backup.rb -n app1 --silent"
end

every 1.days, :at => '1:30 am' do
  command "/root/lxc-backup/backup.rb -n app2 --silent"
end

every 1.days, :at => '2:00 am' do
  command "/root/lxc-backup/backup.rb -n app3 --silent"
end

every 1.days, :at => '2:30 am' do
  command "/root/lxc-backup/backup.rb -n app4 --silent"
end

every 1.days, :at => '3:00 am' do
  command "/root/lxc-backup/backup.rb -n database --silent"
end

every 1.days, :at => '3:30 am' do
  command "/root/lxc-backup/backup.rb -n loadbalancer --silent"
end

every 1.days, :at => '4:00 am' do
  command "/root/lxc-backup/backup.rb -n web1 --silent"
end

# Learn more: http://github.com/javan/whenever
