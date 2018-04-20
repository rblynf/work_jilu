
###
#家居给水管连线
#参数：normal：地平面法向量， zCoordinate：地面z坐标 , high: 管线离地面高度（在上方为正，下方为负）, endPointList : 每个房间的排水立管点坐标
####
class DrainagePipeline
    def run(normal,zCoordinate,high,endPointList)
		# p "Time.now : #{Time.now}"
		#设备属性设置
		@devicePropertys = {
			"洗涤盆,污水盆,污水池" => {"high"=> "475", "pipeDiameter"=> "50"},
			"餐厅,厨房洗菜盆,厨房洗菜池" => {"high"=> "475", "pipeDiameter"=> "50"},
			"单格洗涤盆,单格洗涤池" => {"high"=> "475", "pipeDiameter"=> "50"},
			"双格洗涤盆,双格洗涤池" => {"high"=> "475", "pipeDiameter"=> "50"},
			"盥洗槽" => {"high"=> "475", "pipeDiameter"=> "50"},
			"洗手盆" => {"high"=> "400", "pipeDiameter"=> "50"},
			"洗脸盆" => {"high"=> "400", "pipeDiameter"=> "50"},
			"浴盆" => {"high"=> "500", "pipeDiameter"=> "50"},
			"淋浴器" => {"high"=> "1800", "pipeDiameter"=> "50"},
			"大便器" => {"high"=> "200", "pipeDiameter"=> "DN100"},
			"大便器-冲洗水箱" => {"high"=> "1800", "pipeDiameter"=> "100"},
			"大便器-自闭式冲洗阀" => {"high"=> "800", "pipeDiameter"=> "100"},
			"医用倒便器" => {"high"=> "800", "pipeDiameter"=> "100"},
			"小便器" => {"high"=> "1100", "pipeDiameter"=> "50"},
			"小便器-自闭式冲洗阀" => {"high"=> "1100", "pipeDiameter"=> "50"},
			"小便器-感应式冲洗阀" => {"high"=> "1100", "pipeDiameter"=> "50"},
			"大便槽" => {"high"=> "800", "pipeDiameter"=> "50"},
			"大便槽-≤4个蹲位" => {"high"=> "800", "pipeDiameter"=> "100"},
			"大便槽->4个蹲位" => {"high"=> "800", "pipeDiameter"=> "150"},
			"小便槽" => {"high"=> "1100", "pipeDiameter"=> "50"},
			"小便槽-自动冲洗水箱" => {"high"=> "1800", "pipeDiameter"=> "50"},
			"化验盆" => {"high"=> "1000", "pipeDiameter"=> "50"},
			"净身器" => {"high"=> "200", "pipeDiameter"=> "50"},
			"饮水器" => {"high"=> "1200", "pipeDiameter"=> "50"},
			"家用洗衣机" => {"high"=> "1200", "pipeDiameter"=> "50"}
			}
		#管径大小选择  # 接大便器的排水管管径 ：DN100
		@pipeDiameterHash = {"1"=>"DN50", "2"=>"DN75", "3,4,5,6"=>"DN100"}
		@pipeDiameterHash_new = {}
		@pipeDiameterHash.each{|key,value|
			keys = key.split(",")
			if keys.length > 1
				keys.each{|kItem|
					@pipeDiameterHash_new[kItem] = value
				}
			else
				@pipeDiameterHash_new[key] = value
			end
		}
		@devicePropertysNameList = @devicePropertys.keys
	
        @model = Sketchup.active_model
        @ents = @model.entities
		@model.start_operation "Link Water2 Line Test", true
		#给水点坐标
		@endPointList = endPointList
        @vec_l = [1,0,0]
		@vec_w = [0,1,0]
		#获得房间地面@vec_l和@vec_w向量和地面z坐标
		@zCoordinate = zCoordinate
	
		#移动坐标改变
		vec_l_leng = [0,0,0].distance @vec_l
		vec_w_leng = [0,0,0].distance @vec_w
		@vec_l_xleng = @vec_l[0]/vec_l_leng
		@vec_l_yleng = @vec_l[1]/vec_l_leng
		@vec_l_zleng = @vec_l[2]/vec_l_leng
		@vec_w_xleng = @vec_w[0]/vec_w_leng
		@vec_w_yleng = @vec_w[1]/vec_w_leng
		@vec_w_zleng = @vec_w[2]/vec_w_leng
		
        #需要关注的设备名称
        @attentionEnts = ["洗手盆","洗脸盆","淋浴器","家用洗衣机",
		"污水盆","浴盆","墙","洗涤盆","污水池","单格洗涤盆","单格洗涤池","双格洗涤盆","双格洗涤池",
		"盥洗槽","大便器","大便器-冲洗水箱","大便器-自闭式冲洗阀","医用倒便器","小便器","小便器-自闭式冲洗阀","小便器-感应式冲洗阀",
		"大便槽","大便槽-≤4个蹲位","大便槽->4个蹲位","小便槽","小便槽-自动冲洗水箱","化验盆","净身器","饮水器","家用洗衣机"
		]
		#排水
        @coldEnts = []
        @coldDevicePointList = []
		@coldLinesPoint = []
		#分支端点哈希 key设备端点， value 分支线段
		# @coldbrancheshash = {} 
        
        #获取@ents下的所有组和组件
        @groupList = []
        @instanceList = []
        @ents.each{|item|
           find_group_and_componentinstance(item)
        }
        #遍历组和组件读取其属性并保存

        @attributeHashList = []
        if @groupList.size > 0
			@groupList.each{|item|
				value = item.get_attribute('attributedictionaryname', 'name', 0)
				value2 = item.get_attribute('attributedictionaryname', 'high', 0)
				if value != 0
					attributeHash = {}
					attributeHash["ent"] = item
					
					#包含(但不相等)关注的名称时，改名
					if !@attentionEnts.include?(value)
						@attentionEnts.each{|atem|
							if value.include?(atem)
								value = atem
							end
						}
					end
					attributeHash["name"] = value.to_s
					attributeHash["high"] = value2.to_f.mm
					if value != "墙" && value != "公共区域" && value2.to_i == 0
						if @attentionEnts.include?(value)
							#读取规范的高度属性
							attributeHash["high"] = @devicePropertys["#{value}"]["high"].to_f.mm
						end 
					end
					@attributeHashList << attributeHash
				end
			}
		end 
		if @instanceList.size > 0
			@instanceList.each{|item|
			   value = item.get_attribute('attributedictionaryname', 'name', 0)
			   value2 = item.get_attribute('attributedictionaryname', 'high', 0)
			   if value != 0
					attributeHash = {}
					attributeHash["ent"] = item
					#包含(但不相等)关注的名称时，改名
					if !@attentionEnts.include?(value)
						@attentionEnts.each{|atem|
							if value.include?(atem)
								value = atem
							end
						}
					end
					attributeHash["name"] = value.to_s
					attributeHash["high"] = value2.to_f.mm
					if value != "墙" && value != "公共区域" && value2.to_i == 0
						if  @attentionEnts.include?(value) 
							#读取规范的高度属性
							attributeHash["high"] = @devicePropertys["#{value}"]["high"].to_f.mm
						end 
					end
				   @attributeHashList << attributeHash
			   end
			}
		end
        #遍历@attributeHashList找出需要连线的实体
        @attributeHashList.each{|item|
            if @attentionEnts.include?(item["name"].to_s) && item["name"].to_s != "墙" && item["name"].to_s != "公共区域"
				ahash = {}
				ahash["ent"] = item["ent"]
				ahash["name"] = item["name"]
				ahash["high"] = item["high"]
				@coldEnts << ahash
		    end
        }
		#所有墙面
		@wallFaceList = [] 
		@wallFaceList = find_wall_faces()	
		
		#将有冷热水的设备找出冷热水口的位置（规则靠墙最近的一边为背面，正面为左热右冷（即背面看过去右热左冷））
		@allDeviceClosestResult = {}
		if @coldEnts.size > 0
			@coldEnts.each{|item|
				centerPoint = find_center_in_group(item["ent"],normal,item["high"],1)
				centerPoint = [centerPoint[0]-150.mm,centerPoint[1]+150.mm,centerPoint[2]] #和进水口错开
				closestResults = get_closest_wallFace_result(centerPoint, @wallFaceList, 1000.mm)
				if closestResults.length > 0 
					@allDeviceClosestResult[item] = closestResults
				end
			}
		end 
		
		# p "@allDeviceClosestResult : #{@allDeviceClosestResult}"
		
		#将实体与坐标对应起来，即可根据坐标来查实体（或根据实体查坐标）
		@pointEntHash = {}

        @coldEnts.each{|item|
			coldPoint = 0
			coldPoint = find_center_in_group(item["ent"],normal,item["high"],1)
			coldPoint = [coldPoint[0]-150.mm,coldPoint[1]+150.mm,coldPoint[2]] #和进水口错开
			@coldDevicePointList << coldPoint
			@pointEntHash[coldPoint] = item
        }
		# p "@coldDevicePointList :"
		# show_mm_points(@coldDevicePointList )
		
		#排水管线,先分组再连线
		roomList = [] #所有房间
		@endPointList.each{|item|
			#房间每组
			roomgroup = []
			roomgroup << item
			#选出与排水立管之间没有墙的卫生器具点 
			@coldDevicePointList.each{|dpItem|
				#5米之内的
				item_vi = [item[0],item[1],@zCoordinate+high]
				dpItem_vi = [dpItem[0],dpItem[1],@zCoordinate+high]
				distanceToEnd = dpItem_vi.distance item_vi
				if distanceToEnd < 5000.mm
					device = @pointEntHash[dpItem]
					pointList = []
					flag = false #是否穿墙标志
					if !@allDeviceClosestResult[device].nil?
						vecToWall = @allDeviceClosestResult[device].last
						if vecToWall.dot(@vec_l).abs < 0.1
							pointList = get_link_point_follow_wall(dpItem, item, @vec_w, high)
						else 
							pointList = get_link_point_follow_wall(dpItem, item, @vec_l, high)
						end 
					else
						pointList = get_link_point_follow_wall(dpItem, item, @vec_l, high)
					end
					pointList.each_cons(2){|items|
						items[0] = [items[0][0],items[0][1],@zCoordinate]
						items[1] = [items[1][0],items[1][1],@zCoordinate]
						flag = is_through_walls(items[0],items[1]) if items[0].distance(items[1]) > 0.1
						break if flag 
					}
					if !flag
						roomgroup << dpItem
					end 
				end
			}
			roomList << roomgroup
		}
		#遍历每组，分别连线
		#整理,一个卫生器具只能在一个组中，取最近的
		@coldDevicePointList.each{|dItem|
			count = count_point_in_segments(dItem,roomList)
			if count > 1
				#找到所有包含该器具的组，取距离最近的，其他组删除该元素 
				distance_min = 100000.mm
				roomList.each{|items|
					if items.include?(dItem)
						distance1 = items[0].distance dItem
						if distance1 < distance_min
							distance_min = distance1
						end 
					end 
				}
				roomList.each{|items|
					if items.include?(dItem)
						distance1 = items[0].distance dItem
						if distance1 != distance_min
							items.delete(dItem)
						end 
					end 
				}
			end 
		}
		
# =begin
		@allRoomSegmentList = []
		# p "roomList: #{roomList}"
		roomList.each{|items|
			roomSegmentList = []
			len = items.length
			if len > 1
				(1...len).each{|i|
					device = @pointEntHash[items[i]]
					pointList = []
					if !@allDeviceClosestResult[device].nil?
						vecToWall = @allDeviceClosestResult[device].last
						if vecToWall.dot(@vec_l).abs < 0.1
							pointList = get_link_point_follow_wall(items[i], items[0], @vec_w, high)
						else 
							pointList = get_link_point_follow_wall(items[i], items[0], @vec_l, high)
						end 
					else
						pointList = get_link_point_follow_wall(items[i], items[0], @vec_l, high)
					end
					if pointList.size > 2
						pointList.each_cons(2){|pItems|
							temp_list = [pItems[0], pItems[1]]
							temp_list = remove_repeat_segment(pItems[0], pItems[1], roomSegmentList)
							roomSegmentList << temp_list if temp_list != [0,0]
						}
					end 
				}
			end 
			roomSegmentList = refine_lines(roomSegmentList)
			@allRoomSegmentList << roomSegmentList
			#画线
			roomSegmentList.each{|rItems|
				line = @ents.add_line rItems[0], rItems[1]
				line.material = "yellow" if !line.nil?
			}			
		}
	
		@segmentDiameterHash = {}
		@allRoomSegmentList.each{|roomItemSegments|
			if roomItemSegments.size > 0
				draw_pipe_diameter_to_drainage(roomItemSegments)
			end
		}
	
# =end	 
		# p "@segmentDiameterHash : #{@segmentDiameterHash}"
		# 将管径写入属性中
		@segmentDiameterHash.each{|key,value|
			#找到key对应的Edge实体
			edgeEnt = find_edge_ent_by_segment(key)
			edgeEnt.set_attribute('attributedictionaryname', 'pipeDiameter', "#{value}") if edgeEnt != 0
		}

		@model.commit_operation 
		# p "Time.now end : #{Time.now}"
    end
	
	
  	#找到segment对应的Edge实体
    def find_edge_ent_by_segment(segment)
    	edgeRst = 0
    	if segment.size == 2
    		position1 = Geom::Point3d.new(segment[0])
    		position2 = Geom::Point3d.new(segment[1])
	    	@ents.each{|item|
				if item.typename == "Edge"
					positions = item.start.position
					positione = item.end.position
					if ((position1.distance positions) < 1.mm && (position2.distance positione) < 1.mm) || ((position1.distance positione) < 1.mm && (position2.distance positions) < 1.mm)
						edgeRst = item
					end
				end 
	    	}
    	end
    	edgeRst
    end
	


	#排水管线连接点
	def get_link_point_follow_wall(point1,point2,vec,high)
		pointList = []
		point1_vi = [point1[0],point1[1],@zCoordinate + high]
		point2_vi = [point2[0],point2[1],@zCoordinate + high]
		if vec.dot(@vec_l).abs < 0.1
			line1 = [point1_vi,Geom::Vector3d.new(@vec_w)]
			line2 = [point2_vi,Geom::Vector3d.new(@vec_l)]
		else
			line1 = [point1_vi,Geom::Vector3d.new(@vec_l)]
			line2 = [point2_vi,Geom::Vector3d.new(@vec_w)]
		end 
		point_int = Geom.intersect_line_line line1,line2
		point_int = [point_int[0],point_int[1],point_int[2]] if !point_int.nil?
		pointList << point1
		pointList << point1_vi if !pointList.include?(point1_vi)
		pointList << point_int if !point_int.nil? && !pointList.include?(point_int)
		pointList << point2_vi if !pointList.include?(point2_vi)
		pointList << point2 if !pointList.include?(point2)
		pointList
	end 
	
	

	
	#找出墙面
	def find_wall_faces
		wallFaceList = []
		@attributeHashList.each{|item|
				if item["name"].to_s == "墙"  #
					if item["ent"].typename == "Group"
						item["ent"].entities.each{|item2|
							if item2.typename == "Face" && !item2.normal.samedirection?([0,0,1]) && !item2.normal.samedirection?([0,0,-1])
								wallFaceList << item2	
							end 
						}	
					elsif ent.typename == "ComponentInstance"
						item["ent"].definition.entities.each{|item2|
							if item2.typename == "Face" && !item2.samedirection?([0,0,1]) && !item2.samedirection?([0,0,-1])
								wallFaceList << item2	
							end 
						}	
					end
				end
			}
		wallFaceList
	end 
	
	#在限定的距离内找出最近的墙面
	def get_closest_wallFace_result(point,wallFaceList,limitedDistance)
		resultList = [] #结果，point，交点point_int ,距离 , point到交点的向量
		distance_min = limitedDistance #默认最大的最近距离
		# @model.start_operation "face1" , true
		wallFaceList.each{|wItem|
			fgroup = find_max_group_by_ent(wItem)
			item2point0 = transform_obj(wItem.vertices[0].position,fgroup)
			plane = [item2point0, Geom::Vector3d.new(wItem.normal)]
			line = [point, wItem.normal]
			point_int = Geom.intersect_line_plane(line, plane)
			if !point_int.nil?
				#距离
				point_int = [point_int[0],point_int[1],point_int[2]]
				distancew = point.distance point_int
				#限定距离内的墙面才处理，否则不管
				if distancew <= limitedDistance
					if fgroup != 0
						face1 = transform_face(wItem, fgroup)
					else
						face1 = wItem
					end 
					#交点在墙上
					if face1.classify_point(point_int) == 1 || face1.classify_point(point_int) == 2 || face1.classify_point(point_int) == 4
						#保存距离和point到交点的向量
						if distancew <= distance_min
							distance_min = distancew
							vec = [point_int[0]-point[0],point_int[1]-point[1],point_int[2]-point[2]]
							resultList = [point, point_int, distancew, vec ]
						end 
					end
					if face1 != wItem
						#删除
						face1.edges.each{|face1Item|
							face1Item.erase!
						}
					end 
				end 
			end
		}
		# @model.commit_operation
		resultList
	end 
	
	#将lines细化，如：两线段有交点的应该改为多个线段
	def refine_lines(lines)
		segmentList = []
		lines_c = lines.clone
		intershash = {}
		pointList = []
		lines.each{|item|
			pointList << item[0] if !pointList.include?(item[0])
			pointList << item[1] if !pointList.include?(item[1])
		}
		segmentList = make_new_segments(lines, pointList)
		segmentList
	end 
	
	
	#在一系列线段中找出连接任意两点最短线段列
	def find_shortest_segments_with_two_points(point1,point2,segmentList)
		#遍历所有线段找出与pointList1最后一点相关的线段
		segmentLen = segmentList.length
		flag = true
		
		allRoutelist = [] #元素也是数组
		#从point1开始行走
		#point1连接的线段数
		
		point1Vertex = find_vertex_by_point(point1)
		allRoutelist = get_link_vertex_edges(point1Vertex)
		
		#设置最大线段数为100
		(0..98).each{|count|
			#第count+2步（即最长线段数为count+2）
			allRoutelist = get_link_routes_edges(allRoutelist,count)
		}
	
		allRoutelist_c = allRoutelist.clone
		all_num = allRoutelist.size
		#排除被包含的
		(0...all_num).each{|i|
			(0...all_num).each{|j|
				if i != j && allRoutelist_c[i] != 0 && allRoutelist_c[j] != 0 && allRoutelist_c[i].include?(allRoutelist_c[j].last) 
					jlen = allRoutelist_c[j].length
					if allRoutelist_c[i].include?(allRoutelist_c[j][jlen-2])
						allRoutelist_c.delete_at(j)
						allRoutelist_c.insert(j,0)
					end
				end
			}
		}

		allRoutelist_c.delete(0)
		allRoutelist = allRoutelist_c

		#找出包含目标点point1和point2的线段列 (point1都包含)
		point2Vertex = find_vertex_by_point(point2)
		addressList = [] #目标序列
		allRoutelist.each{|items|
			if items.include?(point2Vertex)
				addressList << items
			end 
		}
		
		lenlistHash = {}
		if addressList != []
			num = addressList.size 
			(0...num).each{|i|
				len_min = 0
				addressList[i].each_cons(2){|items|
					len_min += items[0].position.distance items[1].position
					if items[1] == point2Vertex
						lenlistHash[i] = len_min
						break
					end
				}
			}

			#比较,假设第一个最近
			dmin = lenlistHash[0]
			d_index = 0
			lenlistHash.each{|key,value|
				if value < dmin
					d_index = key
				end
			}

			#取d_index位的线段列，遍历端点，画红线
			# @model.start_operation "Link Shortest segments", true
			# addressList[d_index].each_cons(2){|items|
				# line = @ents.add_line items[0].position, items[1].position
				# line.material = "red" 
				# break if items[1] == point2Vertex
			# }
			# @model.commit_operation 
			addressList[d_index]
		else
			addressList[0]
		end 
		
	end
	
	#获取与一个端点相连的所有边
	def get_link_vertex_edges(vertex)
		alledges = []
		if vertex != 0 && vertex.typename == "Vertex"
			vertexNum = vertex.edges.size			
			(0...vertexNum).each{|i|
				list = []
				list << vertex
				#保存第i条边的另一端点
				if vertex.edges[i].start != vertex
					list << vertex.edges[i].start
				elsif vertex.edges[i].end != vertex
					list << vertex.edges[i].end
				end
				li = change_vertexs_to_points(list)
				alledges << list  
			}
		end
		alledges
	end

	
	#根据坐标来找端点(vertex类型)
	def find_vertex_by_point(point)
		vertex = 0
		@ents.each{|item|
			if item.typename == "Edge"
				item.vertices.each{|item2|
					if item2.position == point
						vertex = item2
					end 
				}
			end 
		}
		vertex
	end 

	
	#获取与给定边相连的所有边
	def get_link_routes_edges(routes, count)
		routeNum = routes.length 
		routes_c = routes.clone
		#重新生成routes
		routes = []
		(0...routeNum).each{|i|
			list_2 = []
			#点数小于步数时
			if routes_c[i].length < count+2 
				routes << routes_c[i]
			else
				if routes_c[i].last.edges.size == 1
					if i == 0 
						routes[0] = routes_c[0]
					else
						routenum2 = routes.length 
						routes << routes_c[i]
					end
				else
					list_2 = get_link_vertex_edges(routes_c[i].last)
					list_2_len = list_2.length 

					#将数组的每一项的最后一个端点保存
					(0...list_2_len).each{|j|
						if !judge_exist_element(routes_c,list_2[j].last) && !judge_exist_element(routes,list_2[j].last)
							if i == 0
								routes_c[0] << list_2[j].last 
								list_temp = routes_c[0].clone
								routes_c[0].pop
								routes << list_temp 
							else
								routes_c[i] << list_2[j].last
								list_temp = routes_c[i].clone
								routes_c[i].pop
								
								routes << list_temp
							end 
						else
							#分情况，1,后退一步，2,形成了闭环。
							flag2 = false
							(0...routes_c.length).each{|k|
								if k != i && routes_c[k].include?(list_2[j][0])
									flag2 = true
								end
							}
							#闭环且其他元素组不包含上一端点
							if !flag2
								routes << routes_c[i]
							end 
						end
					}
				end
			end
		}
		routes
	end 
	 
	

	#标管径s
	def draw_pipe_diameter_to_drainage(roomSegments)
		startPoint = 0
		pointList = []
		roomSegments.each{|items|
			if @endPointList.include?(items[0])
				startPoint = items[0]
			elsif @endPointList.include?(items[1])
				startPoint = items[1]
			end
			pointList << items[0] if !pointList.include?(items[0])
			pointList << items[1] if !pointList.include?(items[1])
		}
		if startPoint != 0
			lines = roomSegments
			devicePointList = @coldDevicePointList
			linesPoint = pointList
			draw_pipe_diameter_common(startPoint,lines,devicePointList,linesPoint)
		end
	end 
	
	
	

	
	def draw_pipe_diameter_common(startPoint,lines,devicePointList,linesPoint)
		#从各个设备点往给水点走，每经过一端点，该端点分支数+1 （树节点模型）
		pointBranceCountHash = {}
		#先将@coldLines细化，如：两线段有交点的应该改为多个线段
		segmentList = []
		segmentList = refine_lines(lines)
		#开始遍历设备点
		allBranceRoutePoins = [] #所有路线点集的数组
		#大便器卫生器具到排水立管之间的线段端点集合
		specialPoints = []
		devicePointList.each{|item|
			vertexs = []
			if !@pointEntHash[item].nil? && @pointEntHash[item]["name"].include?("大便器")
				vertexs = find_shortest_segments_with_two_points(item,startPoint,segmentList)
				specialPoints << change_vertexs_to_points(vertexs)
			else
				vertexs = find_shortest_segments_with_two_points(item,startPoint,segmentList)
				allBranceRoutePoins << change_vertexs_to_points(vertexs)
			end
		}

		if allBranceRoutePoins.length > 0
			allBranceRoutePoins.each{|items|
				items.each{|item|
					if pointBranceCountHash[item].nil?
						pointBranceCountHash[item] = 1
					else
						pointBranceCountHash[item] += 1 
					end
				}
			}
			#整理下
			pkeys = []
			pointBranceCountHash_c = pointBranceCountHash.clone
			pointBranceCountHash.each{|key,value|
				pointBranceCountHash_c.each{|ckey,cvalue|
					if key != ckey && (key.distance ckey) < 1.mm && !pkeys.include?(key) && !pkeys.include?(ckey)
						pointBranceCountHash_c[key] = value + cvalue
						pointBranceCountHash_c[ckey] = value + cvalue
						pkeys << key
						pkeys << ckey
					end
				}
			}
			pointBranceCountHash = pointBranceCountHash_c
			# @model.start_operation "draw line pipe", true
			#端点处标记龙头个数
			# linesPoint.each{|item|
				# pointBranceCountHash.each{|key,value|
					# if (item.distance key) < 1.mm
						# @ents.add_text "#{pointBranceCountHash[key]}", item
						# break
					# end
				# }
			# }
			#取线段两端点标记的龙头个数较小的那个，再据此决定管径大小
			segmentList.each{|items|
				pointCenter = Geom.linear_combination(0.5, items[0], 0.5, items[1])
				num1 = 1
				num2 = 1
				pointBranceCountHash.each{|key,value|
					if (items[0].distance key) < 1.mm
						num1 = pointBranceCountHash[key]
						break
					end
				}
				pointBranceCountHash.each{|key,value|
					if (items[1].distance key) < 1.mm
						num2 = pointBranceCountHash[key]
						break
					end
				}
				# 接大便器的排水管管径 ：DN100
				if judge_exist_element(specialPoints,items[0]) && judge_exist_element(specialPoints,items[1])
					@ents.add_text "DN100", pointCenter
					@segmentDiameterHash[items] = "DN100"
				else
					num_min = num1 <= num2 ? num1 : num2
					@ents.add_text "#{@pipeDiameterHash_new["#{num_min}"]}", pointCenter
					@segmentDiameterHash[items] = @pipeDiameterHash_new["#{num_min}"]
				end
			}
			# @model.commit_operation
		end
	end 
	
	#判断二维数组中是否有某元素
	def judge_exist_element(list,element)
		flag = false #默认没有
		list.each{|items|
			if items.include?(element)
				flag = true
			end 
		}
		flag
	end 
	
	#计算某点在二维点列中出现的次数
	def count_point_in_segments(point,segments)
		count = 0
		segments.each{|segmentItem|
			if segmentItem.include?(point)
				count += 1
			end 
		}
		count
	end 
	
	
	#查看哪些点在线段列上，返回新的线段列
	def make_new_segments(mainsegments, points)
		points.each{|item| 
			flag = false
			mainsegments.each{|segmentItem|
				if (item.distance segmentItem[0]) > 0.1.mm && (item.distance segmentItem[1]) > 0.1.mm
					flag = judge_point_in_segment(item,segmentItem[0],segmentItem[1])
					if flag
						inx = mainsegments.index(segmentItem)
						mainsegments.delete(segmentItem)
						mainsegments.insert(inx, [segmentItem[0], item]) if (item.distance segmentItem[0]) > 1.mm
						mainsegments.insert(inx+1, [item, segmentItem[1]]) if (item.distance segmentItem[1]) > 1.mm
						break
					end
				end
			}
		}
		mainsegments
	end 
	
	#判断某一点是否在两点线段中(point1是否在point2与point3的线段上)
	def judge_point_in_segment(point1,point2,point3)
		flag = false #默认不在
		if point1 == point2 || point1 == point3
			flag = true
		else
			vec12 = Geom::Vector3d.new(point2[0]-point1[0],point2[1]-point1[1],point2[2]-point1[2])
			vec13 = Geom::Vector3d.new(point3[0]-point1[0],point3[1]-point1[1],point3[2]-point1[2])
			if vec12.length > 2.mm && vec13.length > 2.mm && vec12.reverse.samedirection?(vec13)
				flag = true
			end 
		end 
		flag
	end 

	#线段去重,plineList线段组，新增线段端点point1,point2
	def remove_repeat_segment(point1,point2,plineList)
		point1_new = point1 #去重后的端点，默认为初始点
		point2_new = point2
		if plineList.length >= 1
			if !plineList.include?([point1,point2]) && !plineList.include?([point2,point1])
				plineList.each{|item|
					#判断point1是否在线段内
					distance_item01 = item[0].distance item[1]
					distance_p1item0 = point1.distance item[0]
					distance_p1item1 = point1.distance item[1]
					distance_p2item0 = point2.distance item[0]
					distance_p2item1 = point2.distance item[1]
					
					vec_p1item0 = Geom::Vector3d.new(item[0][0]-point1[0],item[0][1]-point1[1],item[0][2]-point1[2])
					vec_p1item1 = Geom::Vector3d.new(item[1][0]-point1[0],item[1][1]-point1[1],item[1][2]-point1[2])
					
					vec_p2item0 = Geom::Vector3d.new(item[0][0]-point2[0],item[0][1]-point2[1],item[0][2]-point2[2])
					vec_p2item1 = Geom::Vector3d.new(item[1][0]-point2[0],item[1][1]-point2[1],item[1][2]-point2[2])
					
					vec_item01 = Geom::Vector3d.new(item[1][0]-item[0][0],item[1][1]-item[0][1],item[1][2]-item[0][2])
					vec_p1p2 = Geom::Vector3d.new(point2[0]-point1[0],point2[1]-point1[1],point2[2]-point1[2])

					#重复则必然四点共线
					#两点均在线段内
					if (vec_p1item0 == Geom::Vector3d.new(0,0,0) || vec_p1item1 == Geom::Vector3d.new(0,0,0) || vec_p1item0.reverse.samedirection?(vec_p1item1)) && (vec_p2item0 == Geom::Vector3d.new(0,0,0) || vec_p2item1 == Geom::Vector3d.new(0,0,0) || vec_p2item0.reverse.samedirection?(vec_p2item1))
						point1_new = 0
						point2_new = 0
						break
					#point1在线段内，point2在线段外
					elsif (vec_p1item0 == Geom::Vector3d.new(0,0,0) || vec_p1item1 == Geom::Vector3d.new(0,0,0) || vec_p1item0.reverse.samedirection?(vec_p1item1)) && vec_p2item0.samedirection?(vec_p2item1)
						#记录离point2近的那个端点
						if point2 != item[0] && point2 != item[1]
							if distance_p2item0 <= distance_p2item1
								point1_new = item[0]
							else
								point1_new = item[1]
							end
						end
					#point2在线段内，point1在线段外
					elsif (vec_p2item0 == Geom::Vector3d.new(0,0,0) || vec_p2item1 == Geom::Vector3d.new(0,0,0) || vec_p2item0.reverse.samedirection?(vec_p2item1)) && vec_p1item0.samedirection?(vec_p1item1)
						#记录离point1近的那个端点
						if point1 != item[0] && point1 != item[1]
							if distance_p1item0 <= distance_p1item1
								point2_new = item[0]
							else
								point2_new = item[1]
							end
						end
					#两点均在线段外
					elsif (vec_p1item0 == Geom::Vector3d.new(0,0,0) || vec_p1item1 == Geom::Vector3d.new(0,0,0) || vec_p1item0.samedirection?(vec_p1item1)) && (vec_p2item0 == Geom::Vector3d.new(0,0,0) || vec_p2item1 == Geom::Vector3d.new(0,0,0) || vec_p2item0.samedirection?(vec_p2item1))
						# p "该情况不符合实际"
						# 有问题
						# puts point1 , point2 
						# p item[0], item[1]
					end
				}
			else #完全重复，无新增线段无需处理
				point1_new = 0
				point2_new = 0
			end
		end

		[point1_new,point2_new]
	end
	
	
	#在端点数组中找离目标端点最近距离的点
	def find_distance_closest_point(oriPoint, points)
		points.delete(oriPoint)
		#离oriPoint最近的点
		distance_min = [points[0][0],points[0][1],oriPoint[2]].distance oriPoint
		points.each{|item|
			disFromS = [item[0],item[1],oriPoint[2]].distance oriPoint
			if disFromS < distance_min
				distance_min = disFromS
			end
		}
		distance_closest_point = 0
		points.each{|item|
			if ([item[0],item[1],oriPoint[2]].distance oriPoint) == distance_min
				distance_closest_point = item
				break
			end
		}
		distance_closest_point
	end
	
	
    #找出群组或组件的底面中点
    def find_center_in_group(ent,normal,high,type, vecToWall = [0,-1,0])
		pointList = []
		group_max = find_max_group_by_ent(ent)
		if ent.typename == "Group"
			#找面的中点
			# ent.entities.each{|item|
				# if item.typename == "Face" && (item.normal.samedirection?(normal) || item.normal.samedirection?(Geom::Vector3d.new(-normal[0],-normal[1],-normal[2])) )
					# item.vertices.each{|item2|
						# pointList << item2.position
					# }
				# end
			# }
			#找外框的底面中心点
			entCenter = ent.bounds.center
			bhigh = ent.bounds.depth
			pointList << [entCenter[0],entCenter[1],entCenter[2] - bhigh/2]
		elsif ent.typename == "ComponentInstance"
			#找面的中点
			# ent.definition.entities.each{|item|
				# if item.typename == "Face" && (item.normal.samedirection?(normal) || item.normal.samedirection?(Geom::Vector3d.new(-normal[0],-normal[1],-normal[2])) )
					# item.vertices.each{|item2|
						# pointList << item2.position
					# }
				# end
			# }
			#找外框的底面中心点
			entCenter = ent.bounds.center
			bhigh = ent.bounds.depth
			pointList << [entCenter[0],entCenter[1],entCenter[2] - bhigh/2]
		end
		#指定高度
		if high == 0
			highmin = pointList[0][2]
			pointList.each{|item|
				if item[2] < highmin
					highmin = item[2]
				end
			}
		else
			highmin = high
		end

		centerPoint = ent.bounds.center
		if type == 1
			downCenterPoint = [centerPoint[0],centerPoint[1],highmin]
			downCenterPoint = transform_obj(downCenterPoint,group_max)
			return downCenterPoint
		elsif type == 2
			#先整理向量vecToWall，<0.1的部分视为0
			vecToWall_vi = vecToWall.clone
			if vecToWall[1] != 0 && (vecToWall[0]/vecToWall[1]).abs > 50
				vecToWall_vi[1] = 0
			end 
			if vecToWall[0] != 0 && (vecToWall[1]/vecToWall[0]).abs > 50
				vecToWall_vi[0] = 0
			end 

			vecToWall_vi = Geom::Vector3d.new(vecToWall_vi)
			if vecToWall_vi.samedirection?(@vec_l) 
				downCenterPoints = [[centerPoint[0],centerPoint[1]+75.mm,highmin], [centerPoint[0],centerPoint[1]-75.mm,highmin]]
				downCenterPoints = [transform_obj(downCenterPoints[0],group_max), transform_obj(downCenterPoints[1],group_max)]
			elsif vecToWall_vi.samedirection?(@vec_w)
				downCenterPoints = [[centerPoint[0]-75.mm,centerPoint[1],highmin], [centerPoint[0]+75.mm,centerPoint[1],highmin]]
				downCenterPoints = [transform_obj(downCenterPoints[0],group_max), transform_obj(downCenterPoints[1],group_max)]
			elsif vecToWall_vi.reverse.samedirection?(@vec_l)
				downCenterPoints = [[centerPoint[0],centerPoint[1]-75.mm,highmin], [centerPoint[0],centerPoint[1]+75.mm,highmin]]
				downCenterPoints = [transform_obj(downCenterPoints[0],group_max), transform_obj(downCenterPoints[1],group_max)]
			elsif vecToWall_vi.reverse.samedirection?(@vec_w)
				downCenterPoints = [[centerPoint[0]+75.mm,centerPoint[1],highmin], [centerPoint[0]-75.mm,centerPoint[1],highmin]]
				downCenterPoints = [transform_obj(downCenterPoints[0],group_max), transform_obj(downCenterPoints[1],group_max)]
			end 
			#间距150.mm
			return downCenterPoints
		end
    end
    
	
    #找出包含指定实体的最大群组或组件，以获取实际坐标
    def find_max_group_by_ent(ent)
		targetGroupList = []
		targetGroup = 0
		@ents.each{|item|
			if item.typename == "Group"
				item.entities.each{|item2|
					if item2 == ent
						targetGroup = item
						targetGroupList << item
					elsif item2.typename == "Group" 
						item2.entities.each{|item3|
							if item3 == ent
								targetGroup = item2
								targetGroupList << item
								targetGroupList << item2
							elsif item3.typename == "Group"
								item3.entities.each{|item4|
									if item4 == ent
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}	
							elsif item3.typename == "ComponentInstance"
								item3.definition.entities.each{|item4|
									if item4 == ent
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}	
							end
						}
					elsif item2.typename == "ComponentInstance" 
						item2.definition.entities.each{|item3|
							if item3 == ent
								targetGroup = item2
								targetGroupList << item
								targetGroupList << item2
							elsif item3.typename == "Group" 
								item3.entities.each{|item4|
									if item4 == ent
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}
							elsif item3.typename == "ComponentInstance" 
								item3.definition.entities.each{|item4|
									if item4 == ent
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}
							end
						}
					end 
				}
			
			end
		}
		tGroup = 0
    	tGroup = targetGroupList[0] if targetGroupList != []
		tGroup
		# targetGroupList[0]
    end
	
    
    def find_group_and_componentinstance(ent)
        if ent.typename == "Group"
            @groupList << ent
                ent.entities.each{|item|
                    find_group_and_componentinstance(item)
                }
        elsif ent.typename == "ComponentInstance"
             @instanceList << ent
             ent.definition.entities.each{|item|
                find_group_and_componentinstance(item)
             }
        end
    end
    

	#端点数组去重
	def uniq_point_list(pointList)
		pointList_new = []
		pLen = pointList.length
		#要删除的端点
		if pLen > 2
			deletePoints = []
			pointList_c = pointList.clone
			(0...pLen).each{|i|
				(0...pLen).each{|j|
					if i != j 
						if (pointList[i].distance pointList_c[j]) < 0.1.mm
							deletePoints << pointList[i] if !deletePoints.include?(pointList[i])
						end 
					end 
				}
			}
			deletePoints.each{|item|
				inx = pointList.index(item)
				pointList.delete(item)
				pointList.insert(inx, item)
			}
		end 
		pointList_new = pointList
		pointList_new
	end 
	

	
	#点到线段的距离
	def distance_from_point_to_segment(point,segment)
		point =	Geom::Point3d.new(point[0],point[1],point[2])
		distance = 100000.mm
		vec = Geom::Vector3d.new(segment[1][0]-segment[0][0],segment[1][1]-segment[0][1],segment[1][2]-segment[0][2])
		line1 = [segment[0],Geom::Point3d.new(segment[1])]
		if vec.dot(@vec_l) < 0.1
			vec_vi = @vec_l
		elsif vec.dot(@vec_w) < 0.1
			vec_vi = @vec_w
		end 
		line2 = [point,Geom::Vector3d.new(vec_vi)]
		point_int = Geom.intersect_line_line(line1, line2)
		distance = point.distance point_int if !point_int.nil?
		distance
	end 

	
	#三点路径结合（删除重复线段）
	def combinate_point_path(points)
		points_c = points.clone
		if points.size > 2
			points.each_cons(3){|items|
				vec1 = Geom::Vector3d.new(items[1][0]-items[0][0],items[1][1]-items[0][1],items[1][2]-items[0][2]) 
				vec2 = Geom::Vector3d.new(items[2][0]-items[1][0],items[2][1]-items[1][1],items[2][2]-items[1][2]) 
				if vec1.length > 0.1.mm && vec2.length > 0.1.mm
					if vec1.reverse.samedirection?(vec2) || vec1.samedirection?(vec2)
						#删除中间点
						points_c.delete(items[1])
					end 
				# elsif vec1.length < 0.1.mm || vec2.length < 0.1.mm
					# inx = points_c.index(items[1])
					# points_c.delete(items[1])
					# points_c.insert(inx,items[1])
				end
			}
		end
		points_c
	end
	
	
	#删除数组中重复的元素，非uniq!
	def delete_repeated(array)
		countHash = Hash.new(0)
		array.each{|val|
		countHash[val]+=1
		}
		countHash.reject{|val,count|count==1}.keys
	end
	

	#查找当前模型地面face面积相等的数量最多的face(也就是地板瓷砖),由此确定房间的长宽向量及地板z坐标
	def searcher_face_most_num(normal)
		faceList = []
		areaList = []
		@ents.each{|item|
			if item.typename == "Face"
				faceList << item
				areaList << item.area
			elsif item.typename == "Group" 
				item.entities.each{|item2|
					if item2.typename == "Face" && (item2.normal.samedirection?(normal) || item2.normal.samedirection?(Geom::Vector3d.new(-normal[0],-normal[1],-normal[2])))
						faceList << item2
						areaList << item2.area
					elsif item2.typename == "Group" 
						item2.entities.each{|item3|
							if item3.typename == "Face" && (item3.normal.samedirection?(normal) || item3.normal.samedirection?(Geom::Vector3d.new(-normal[0],-normal[1],-normal[2])))
								faceList << item3
								areaList << item3.area		
							elsif item3.typename == "Group" 
								item3.entities.each{|item4|
									if item4.typename == "Face" && (item4.normal.samedirection?(normal) || item4.normal.samedirection?(Geom::Vector3d.new(-normal[0],-normal[1],-normal[2])))
									faceList << item4
										areaList << item4.area		
									end
								}
							end
						}
					elsif item2.typename == "ComponentInstance"
						item2.definition.entities.each{|dItem|
							if dItem.typename == "Face" && (dItem.normal.samedirection?(normal) || dItem.normal.samedirection?(Geom::Vector3d.new(-normal[0],-normal[1],-normal[2])))
								faceList <<	dItem
								areaList << dItem.area	
							elsif dItem.typename == "Group" 
								dItem.entities.each{|dItem2|
									if dItem2.typename == "Face" && (dItem2.normal.samedirection?(normal) || dItem2.normal.samedirection?(Geom::Vector3d.new(-normal[0],-normal[1],-normal[2])))
										faceList <<	dItem2
										areaList << dItem2.area	
									end
								}
							elsif dItem.typename == "ComponentInstance" 
							
							end
						}
					end
				}
			end 
		}
		#遍历面积数组，取相等数量最多的值
		areaNumhash = {}
		areaList.each{|item|
			if !areaNumhash.keys.include?(item)
				areaNumhash[item] = 1
			else
				areaNumhash[item] += 1
			end
		}
		areaMostNum = 30
		mostNumArea = 0
		areaNumhash.each{|key,value|
			if value > areaMostNum
				areaMostNum = value
				mostNumArea = key
			end
			# if value > 30
				# p key.to_mm.to_mm ,value
			# end
		}
		targetFace = 0
		faceList.each{|item|
			if item.area == mostNumArea
				targetFace = item
				# break
			end
		}
		#找targetFace 所在的组
		targetGroup = 0
		targetGroupList = []
		@ents.each{|item|
			if item.typename == "Group"
				item.entities.each{|item2|
					if item2 == targetFace
						targetGroup = item
						targetGroupList << item
					elsif item2.typename == "Group" 
						item2.entities.each{|item3|
							if item3 == targetFace
								targetGroup = item2
								targetGroupList << item
								targetGroupList << item2
							elsif item3.typename == "Group"
								item3.entities.each{|item4|
									if item4 == targetFace
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}	
							elsif item3.typename == "ComponentInstance"
								item3.definition.entities.each{|item4|
									if item4 == targetFace
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}	
							end
						}
					elsif item2.typename == "ComponentInstance" 
						item2.definition.entities.each{|item3|
							if item3 == targetFace
								targetGroup = item2
								targetGroupList << item
								targetGroupList << item2
							elsif item3.typename == "Group" 
								item3.entities.each{|item4|
									if item4 == targetFace
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}
							elsif item3.typename == "ComponentInstance" 
								item3.definition.entities.each{|item4|
									if item4 == targetFace
										targetGroup = item3
										targetGroupList << item
										targetGroupList << item2
										targetGroupList << item3
									end
								}
							end
						}
					end 
				}
			
			end
		}
		targetFace.vertices.each{|item|
			pointItem0 = transform_obj(item.position,targetGroupList[0])
		}
		position_new = transform_obj(targetFace.vertices[0].position,targetGroupList[0])
		@zCoordinate = position_new[2]
		# p "@@"
		# puts @zCoordinate
		vec_l = [targetFace.vertices[0].position[0]-targetFace.vertices[1].position[0],targetFace.vertices[0].position[1]-targetFace.vertices[1].position[1],targetFace.vertices[0].position[2]-targetFace.vertices[1].position[2]]
		vec_w = [targetFace.vertices[2].position[0]-targetFace.vertices[1].position[0],targetFace.vertices[2].position[1]-targetFace.vertices[1].position[1],targetFace.vertices[2].position[2]-targetFace.vertices[1].position[2]]
		[vec_l, vec_w]
	end

	
	#将组里端点坐标转为组外坐标
	def transform_obj(obj, entity)
		return obj unless entity
		return obj if entity == 0
		tran = Geom::Transformation.new
		trans = entity.transformation*tran
		obj.transform trans
	end
	
	
	#将组内平面模型坐标转为组外平面模型坐标
	def transform_face(face,entity)
		points = []
		face.vertices.each{|item|
			points << transform_obj(item.position, entity)
		}
		points << points[0]
		face1 = @ents.add_face points
		face1
	end 
	
	#穿墙判断
	def is_through_walls(point1,point2)
		vec12 = Geom::Vector3d.new(point2[0]-point1[0], point2[1]-point1[1], point2[2]-point1[2])
		line1 = [point1, Geom::Point3d.new(point2)]
		distance12 = point1.distance point2
		flag = false #穿墙标志
		if vec12.length > 0 && !vec12.samedirection?([0,0,1]) && !vec12.samedirection?([0,0,-1])
			@wallFaceList.each{|item2|
				fgroup = find_max_group_by_ent(item2)
				item2point0 = transform_obj(item2.vertices[0].position,fgroup)
				item2point0 = [item2point0[0],item2point0[1],point1[2]]
				plane = [item2point0, Geom::Vector3d.new(item2.normal)]
				point_vi = Geom.intersect_line_plane(line1,plane)

				if !point_vi.nil?
					#交点在线段上并且在墙上
					distance1_vi = point1.distance point_vi
					distance2_vi = point2.distance point_vi
					if fgroup != 0
						face1 = transform_face(item2, fgroup)
					else
						face1 = item2
					end 
					if (distance1_vi <= distance12) && (distance2_vi <= distance12) && (face1.classify_point(point_vi) == 1 || face1.classify_point(point_vi) == 2 || face1.classify_point(point_vi) == 4)
						flag = true 
					end
					if face1 != item2
						#删除
						face1.edges.each{|face1Item|
							face1Item.erase!
						}
					end 
				end
			}	
		end
		flag
	end
	 

	#两点线段检索附近是否有与水管同向的过道，有的话优先从过道走
	def search_corridor(point1, point2, distance)
		line12 = [Geom::Point3d.new(point1),Geom::Point3d.new(point2)]
		vec12 = Geom::Vector3d.new(point2[0]-point1[0],point2[1]-point1[1],point2[2]-point1[2])
		if vec12.samedirection?(@vec_l) || vec12.reverse.samedirection?(@vec_l) || vec12.samedirection?(@vec_w) || vec12.reverse.samedirection?(@vec_w)
			# @corridorFaceList.each{|corridorFaceItem|
				# corridorFaceItem["ent"].vertices.each{|pItem|
					# dist = pItem.distance_to_line line12
					# if dist <= distance && corridorFaceItem["vec"] == vec12
						#有过道，走过道
						
					# end
				# }
			
			# }
		end 
	end 

	#vertexs数组类型转换为坐标数组类型	
	def change_vertexs_to_points(vertexsList)
		list = []
		if vertexsList.to_s.length > 0
			vertexsList.each{|item|
				list << [item.position[0],item.position[1],item.position[2]]
			}
		end
		list
	end 

	#画线
	def draw_line_by_segments(segemnts,type)
		# @model.start_operation "Draw Line", true
		segemnts.each{|items|
			line = @ents.add_line items[0], items[1]
			if type == "hot"
				line.material = "red" if !line.nil?
			end 
		}
		# @model.commit_operation
	end 
	
	#画线
	def draw_line_by_points(points,type)
		points.each_cons(2){|items|
			line = @ents.add_line items[0], items[1]
			if type == "hot"
				line.material = "red" 
			end 
		}
	end 
	
	#
	def show_mm_points(points)
		points_2 = []
		points.each{|item|
			points_2 << [item[0].to_mm,item[1].to_mm,item[2].to_mm]
		}
		p points_2
	end
	
	#显示端点列的坐标.mm
	def show_mm_vertexs(vertexsList)
		list = []
		vertexsList.each{|item|
			list << item.position
		}
		show_mm_points(list)
		list
	end 
	
end 

DrainagePipeline.new.run([0,0,1], 0.mm, -300.mm,[[5608.mm, 3292.mm,1000.mm],[-1267.mm,-1834.mm,500.mm],[-1272.mm,2602.mm,600.mm]])