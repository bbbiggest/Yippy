platform :osx, '12.0'

project 'Yippy', {
  'Debug' => :debug,
  'Release' => :release,
  'Beta Debug' => :debug,
  'Beta Release' => :release,
  'XCTest' => :debug
}

target 'Yippy' do
    # Comment the next line if you don't want to use dynamic frameworks
    use_frameworks!

    # Pods for Yippy
    pod 'Default'
    pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git', :tag => 'v2.5.0'
    pod 'RxSwift', '~> 5'
    pod 'RxCocoa', '~> 5'

    target 'YippyTests' do
        inherit! :search_paths
        # Pods for testing
        pod 'RxBlocking', '~> 5'
        pod 'RxTest', '~> 5'
        pod 'Default'
        pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git', :tag => 'v2.5.0'
        pod 'RxSwift', '~> 5'
        pod 'RxCocoa', '~> 5'
    end

    target 'YippyUITests' do
        inherit! :search_paths
        # Pods for testing
        pod 'RxBlocking', '~> 5'
        pod 'RxTest', '~> 5'
        pod 'Default'
        pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git', :tag => 'v2.5.0'
        pod 'RxSwift', '~> 5'
        pod 'RxCocoa', '~> 5'
    end
end

# Xcode 27 requires macOS 12 or later, including embedded pod targets.
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            deployment_target = config.build_settings['MACOSX_DEPLOYMENT_TARGET']
            if deployment_target.nil? || Gem::Version.new(deployment_target) < Gem::Version.new('12.0')
                config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'
            end
        end
    end
end
