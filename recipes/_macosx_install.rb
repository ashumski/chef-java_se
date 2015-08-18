extend Chef::Mixin::ShellOut

# inspiration from https://github.com/caskroom/homebrew-cask/blob/master/Casks/java.rb
unless shell_out("pkgutil --pkgs='com.oracle.jdk#{node['java_se']['jdk_version']}'").exitstatus == 0
  version = node['java_se']['version']

  name = "JDK #{version.split('.')[1]} Update #{version.sub(/^.*?_(\d+)$/, '\1')}"
  execute "hdiutil attach '#{node['java_se']['file']}' -quiet"

  avoid_daemon = Gem::Version.new(node['platform_version']) >= Gem::Version.new('10.8')
  execute "sudo installer -pkg '/Volumes/#{name}/#{name}.pkg' -target /" do
    # Prevent cfprefsd from holding up hdiutil detach for certain disk images
    environment('__CFPREFERENCES_AVOID_DAEMON' => '1') if avoid_daemon
  end

  execute "hdiutil detach '/Volumes/#{name}' || hdiutil detach '/Volumes/#{name}' -force"

  #
  # make minor modifications to the JRE to prevent issues with packaged applications,
  # as discussed here: https://bugs.eclipse.org/bugs/show_bug.cgi?id=411361
  #

  %w(BundledApp JNI WebStart Applets).each do |str|
    execute "/usr/bin/sudo /usr/libexec/PlistBuddy -c \"Add :JavaVM:JVMCapabilities: string #{str}\" " \
       "/Library/Java/JavaVirtualMachines/jdk#{version}.jdk/Contents/Info.plist"
  end

  execute '/usr/bin/sudo /bin/rm -rf /System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK'

  execute "/usr/bin/sudo /bin/ln -nsf /Library/Java/JavaVirtualMachines/jdk#{version}.jdk/Contents " \
      '/System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK'

  execute "/usr/bin/sudo /bin/ln -nsf /Library/Java/JavaVirtualMachines/jdk#{version}.jdk/Contents/Home " \
      '/Library/Java/Home'

  execute '/usr/bin/sudo /bin/mkdir -p ' \
      "/Library/Java/JavaVirtualMachines/jdk#{version}.jdk/Contents/Home/bundle/Libraries"

  execute "/usr/bin/sudo /bin/ln -nsf /Library/Java/JavaVirtualMachines/jdk#{version}.jdk/Contents" \
      "/Home/jre/lib/server/libjvm.dylib /Library/Java/JavaVirtualMachines/jdk#{version}.jdk/Contents" \
      '/Home/bundle/Libraries/libserver.dylib'
end