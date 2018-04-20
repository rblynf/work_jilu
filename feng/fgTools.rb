require 'find'
unless file_loaded?(__FILE__)
    face_toolbar = UI::Toolbar.new "FG Pipe Line"
    wl_cmd = UI::Command.new("FG Pipe Line"){
        path = File.join(File.dirname(__FILE__).force_encoding("utf-8"),'fengPipeTools', 'Ruby')
        Find.find(path) { |filename| 
            load filename if File.file?(filename) 
        
        }
        load File.join(File.dirname(__FILE__), "/fengPipeTools/GroundFLine.rb")
        GroundFLine::MyFLine.new
        GroundFLine::MyFLine.show
    }
    face_toolbar.add_item wl_cmd
    face_toolbar.show
end