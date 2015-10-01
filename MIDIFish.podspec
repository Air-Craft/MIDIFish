Pod::Spec.new do |s|

  s.name         = "MIDIFish"
  s.version      = "0.1.0"
  s.summary      = "Clean and clear iOS MIDI including Wi-Fi."

  s.description  = <<-DESC
                   CoreMIDI is complex and arguably convoluted, especially for the 
                   requirements of most iOS apps. This library simplifies the semantics
                   and brings it under a clear object model.

                   NOTE, while this library is being used in production, it's still very
                   beta and not entirely feature complete (eg. MIDI Receive has not been implemented)

                   Props to PGMidi, the Guru of nearly all of us CoreMIDI hackers
                   DESC

  s.homepage     = "https://github.com/Air-Craft/MIDIFish"

  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Hari Karam Singh" => "singh@air-craft.co" }
  s.social_media_url   = "http://twitter.com/AirCraftHQ"

  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/Air-Craft/MIDIFish.git", :tag => "0.1.0" }

  s.source_files  = "MIDIFish/**/*.{h,m}"
  s.public_header_files = "MIDIFish/*.h"
  s.resource  = "MIDIFish/Localizable.strings"

  s.frameworks  = "Foundation", "CoreMIDI"

  s.requires_arc = true

end
