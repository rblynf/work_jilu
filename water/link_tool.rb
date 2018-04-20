class Link_Tool
	def initialize(params)
		@params = params	
	end

	def activate
		obj = defined?(::Struct::LinkParams) ?
        Struct::LinkParams :
        Struct.new('LinkParams',
					:pointList, #待连接点列
					:normal,
					:high # 离地高度
				) 
		@link_obj = obj.new
		@link_obj.high = @params['离地高度'].to_f.mm
		@link_obj.normal = [0,0,1]
		@ptList = []
		@len = @params["几点连线"].to_i
		if @len > 1
			(0...@len).each{|i|
				@ptList[i] = Sketchup::InputPoint.new
			}
			@count = 0 #点击计数器
			@link_obj.pointList = []
		end
	end

	# If the user clicked, draw a line
	def onMouseMove flags, x, y, view
		if @count == @len-1
			 @ptList[@len-1].pick view, x, y, @ptList[@len-2]    
			 view.invalidate
		end
	end
	
	def onLButtonDown flags, x, y, view
		if @count == @len-1
			@ptList.each{|item|
				@link_obj.pointList << item.position
			}
			draw_waterPipeLine
		else
			if @count == 0
				@ptList[@count].pick view, x, y
			else
				@ptList[@count].pick view, x, y, @ptList[@count-1] 
			end
			@count += 1
		end
	end
	
	def draw view
     
	end

	# Draw line follow wall
	def draw_waterPipeLine
		WaterPipeLine2.new.run(@link_obj.pointList,
						@link_obj.normal,
						@link_obj.high
						)
		reset
	end

	# Return to original state
	def reset
		@ptList.each{|item|
			item.clear
		}
		@count = 0
		@link_obj.pointList = [] 
	end

	# Respond when user presses Escape
	def onCancel flags, view
		reset
	end  


end