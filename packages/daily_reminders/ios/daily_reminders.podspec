Pod::Spec.new do |s|
  s.name = 'daily_reminders'
  s.version = '1.0.0'
  s.summary = 'Daily task summaries for Remind Me.'
  s.description = s.summary
  s.homepage = 'https://example.com/remindme'
  s.license = { :type => 'Private' }
  s.author = { 'Remind Me' => 'remindme@example.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
end
