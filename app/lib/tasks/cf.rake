namespace :cf do
  desc "Only run on the first application instance"
  task :on_first_instance do
    instance_index = Integer(ENV["CF_INSTANCE_INDEX"])
    exit(0) unless instance_index == 0
  rescue
    exit(0)
  end
end
