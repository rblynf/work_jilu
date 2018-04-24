currentPath = File.dirname(__FILE__)
load File.join(currentPath,"/CSVData.rb")
load File.join(currentPath,"/TXTData.rb")
load File.join(currentPath,'timeOutTest.rb')
# ###
#家居给水管连线
#参数：normal：地平面法向量， zCoordinate：地面z坐标 , high: 管线离地面高度（在上方为正，下方为负）, startPoint :初始给水点坐标
#      pipeMaterialType: 水管材料类型, houseType：住宅类型，dql：日最高额定用水， personNum: 人数, useTime:使用时间
####
class WaterSupplyPipeline
    def run(normal,zCoordinate,high,startPoint,pipeMaterialType,houseType,dql,personNum,useTime)
        #计算管径需要用到的参数
        @pipeMaterialType = pipeMaterialType
        @houseType = houseType.to_f
        @dql = dql.to_f
        @personNum = personNum.to_f
        @useTime = useTime.to_f
        @kh = get_kh_by_dql(@houseType,@dql)
        @supplyFitInfoHash  = get_supply_and_fit_info
        @u0acHash = get_u0_to_ac_info
        @dnPipeHash = get_dn_to_pipe_info
        @dnVHash = get_dn_to_v_info

		#卫生器具属性设置 ，主要用来的定位高度
		@devicePropertys = {"洗手盆"=>{"high"=>"550","pipeDiameter"=>"DN15"},
			"洗脸盆" => {"high"=>"550", "pipeDiameter"=>"DN15"},
			"淋浴器" => {"high"=>"1150", "pipeDiameter"=>"DN15"},
			"坐便器" => {"high"=>"150", "pipeDiameter"=>"DN15"},
			"厨房洗涤盆" => {"high"=>"450", "pipeDiameter"=>"DN15"},
			"洗衣机" => {"high"=>"1200", "pipeDiameter"=>"DN15"},
			"热水器" => {"high"=>"1200", "pipeDiameter"=>"DN15"},
			"浴盆" => {"high"=>"600", "pipeDiameter"=>"DN15"},
			"大便器" => {"high"=>"550", "pipeDiameter"=>"DN25"},
			"小便器" => {"high"=>"1170", "pipeDiameter"=>"DN15"}
			}
		#管径大小选择
		@pipeDiameterHash = {"1"=>"DN15", "2,3"=>"DN20", "4,5,6"=>"DN25", "7,8,9,10"=>"DN32"}
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
		@model.start_operation "Link Supply Water Line ", true
		#给水点坐标
		@startPoint = startPoint
        # @vec_l = [1,1,0]
		# @vec_w = [-1,1,0]
		@vec_l = [1,0,0]
		@vec_w = [0,1,0]
		#获得房间地面@vec_l和@vec_w向量和地面z坐标
		@zCoordinate = zCoordinate

		# houseVecList = searcher_face_most_num(normal)
		# if houseVecList[0] && houseVecList[1]
			# @vec_l = houseVecList[0]
			# @vec_w = houseVecList[1]
		# end
	
		#移动坐标改变
		vec_l_leng = [0,0,0].distance @vec_l
		vec_w_leng = [0,0,0].distance @vec_w
		@vec_l_xleng = @vec_l[0]/vec_l_leng
		@vec_l_yleng = @vec_l[1]/vec_l_leng
		@vec_l_zleng = @vec_l[2]/vec_l_leng
		@vec_w_xleng = @vec_w[0]/vec_w_leng
		@vec_w_yleng = @vec_w[1]/vec_w_leng
		@vec_w_zleng = @vec_w[2]/vec_w_leng
		
        #需要关注的实体
        @attentionEnts = ["洗手盆","洗脸盆","淋浴器","水龙头","坐便器","厨房洗涤盆","洗衣机","热水器","浴盆","大便器","小便器","墙"]
        #冷热水管分开
        @coldEnts = []
        @hotAndColdEnts = []
        @hotDevicePointList = []
        @coldDevicePointList = []
		@coldLinesPoint = []
		@hotLinesPoint = []
		
		#分支端点哈希 key设备端点， value 分支线段
		@coldbrancheshash = {} 
        
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
				value3 = item.get_attribute('attributedictionaryname', 'coldAndHot', 0)
                value4 = item.get_attribute('attributedictionaryname', 'ql', 0)
                value5 = item.get_attribute('attributedictionaryname', 'supplyFittingName', 0)
                
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
                            # p "@devicePropertys["#{value}"]["high"] "
                            # p "value: #{value}"
                            # p @devicePropertys["#{value}"]                   
							attributeHash["high"] = @devicePropertys["#{value}"]["high"].to_f.mm
						end 
					end
					attributeHash["coldAndHot"] = value3.to_i 
                    attributeHash["ql"] = value4.to_f
                    attributeHash["supplyFittingName"] = value5
					@attributeHashList << attributeHash
				end
			}
		end 
		if @instanceList.size > 0
			@instanceList.each{|item|
			   value = item.get_attribute('attributedictionaryname', 'name', 0)
			   value2 = item.get_attribute('attributedictionaryname', 'high', 0)
			   value3 = item.get_attribute('attributedictionaryname', 'coldAndHot', 0)
               value4 = item.get_attribute('attributedictionaryname', 'ql', 0)
               value5 = item.get_attribute('attributedictionaryname', 'supplyFittingName', "")
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
				    attributeHash["coldAndHot"] = value3.to_i  
                    attributeHash["ql"] = value4.to_f
                    attributeHash["supplyFittingName"] = value5
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
                ahash["ql"] = item["ql"]
                ahash["supplyFittingName"] = item["supplyFittingName"]
				@coldEnts << ahash
                #判断是否有热水管
                @hotAndColdEnts << ahash if item["coldAndHot"].to_i != 0
            end
        }
		#所有墙面
		@wallFaceList = [] 
		
		@wallFaceList = find_wall_faces_2()

        #实际组外墙的坐标
        @wallFaceListRel = []
        @wallFaceList.each{|fItem|
            fgroup = find_max_group_by_ent(fItem)
            face1 = 0
            if fgroup != 0
                face1 = transform_face(fItem, fgroup)
            else
                face1 = fItem
            end 
            @wallFaceListRel << face1
        }

		
		#将有冷热水的设备找出冷热水口的位置（规则靠墙最近的一边为背面，正面为左热右冷）
		@allDeviceClosestResult = {}
		if @coldEnts.size > 0
			@coldEnts.each{|item|
				centerPoint = find_center_in_group(item["ent"],normal,item["high"],1)
				# 找出附近1米内的墙（1000.mm）,再找出最近的
				closestResults = get_closest_wallFace_result(centerPoint, @wallFaceListRel, 1000.mm)
				if closestResults.length > 0 
					@allDeviceClosestResult[item] = closestResults
				end
			}
		end 
		# p "@allDeviceClosestResult: #{@allDeviceClosestResult}"
		#将实体与坐标对应起来，即可根据坐标来查实体（或根据实体查坐标）
		@pointEntHash = {}
		#墙上立管点（允许穿墙的点）, 映射到1米内墙上的点，若无墙，则为原点
		@coldAllowWallPointList = []
		@hotAllowWallPointList = []

        @coldEnts.each{|item|
			coldPoint = 0
			#若是含有冷热水的实体则要取两点
			if @hotAndColdEnts.include?(item)
				if !@allDeviceClosestResult[item].nil?
					vecToWall = @allDeviceClosestResult[item].last
					coldPoint = find_center_in_group(item["ent"],normal,item["high"],2,vecToWall)[1] #冷水口
					#对应到墙上的点
					allowWallPoint = get_point_move_by_vector(coldPoint,vecToWall)
					@coldAllowWallPointList << allowWallPoint
                    @pointEntHash[allowWallPoint] = item #墙上的点也对应设备
				else
					coldPoint = find_center_in_group(item["ent"],normal,item["high"],2,[-@vec_w[0],-@vec_w[1],-@vec_w[2]])[1] #冷水口
					@coldAllowWallPointList << coldPoint
				end 
			else
				if !@allDeviceClosestResult[item].nil?
					vecToWall = @allDeviceClosestResult[item].last
					coldPoint = find_center_in_group(item["ent"],normal,item["high"],1,vecToWall)
					#对应到墙上的点
					allowWallPoint = get_point_move_by_vector(coldPoint,vecToWall)
					@coldAllowWallPointList << allowWallPoint
                    @pointEntHash[allowWallPoint] = item #墙上的点也对应设备
				else
					coldPoint = find_center_in_group(item["ent"],normal,item["high"],1)
					@coldAllowWallPointList << coldPoint
				end
			end
			@coldDevicePointList << coldPoint
			@pointEntHash[coldPoint] = item
        }
		@hotAndColdEnts.each{|item|
			hotPoint = 0
			if !@allDeviceClosestResult[item].nil?
				vecToWall = @allDeviceClosestResult[item].last
				hotPoint = find_center_in_group(item["ent"],normal,item["high"],2,vecToWall)[0] #热水口
				#对应到墙上的点
				allowWallPoint = get_point_move_by_vector(hotPoint,vecToWall)
				@hotAllowWallPointList << allowWallPoint
                @pointEntHash[allowWallPoint] = item #墙上的点也对应设备
			else
				hotPoint = find_center_in_group(item["ent"],normal,item["high"],2,[-@vec_w[0],-@vec_w[1],-@vec_w[2]])[0] #热水口
				@hotAllowWallPointList << hotPoint
			end 
			@hotDevicePointList << hotPoint
			@pointEntHash[hotPoint] = item
        }
		
		#冷热水管线
		@coldLines = [] 
		@hotLines = []
		@hotmainlineList = [] #主管道
		@coldmainlineList = []

		# p "@coldDevicePointList: "
		# show_mm_points(@coldDevicePointList)
		# p "@hotDevicePointList: "
		# show_mm_points(@hotDevicePointList)
	
        begin 
            if @coldDevicePointList.length >= 2
    			get_coldorhot_link_points(@coldDevicePointList,"cold",high)
    		end 

    		#将立管靠墙
    		@coldLines = stand_against_wall(@coldLines)
            #为确保线段表示最优，再做次细分
            @coldLines = refine_lines(@coldLines)

    		@coldLines.each{|citems|
    			@coldLinesPoint << citems[0] if !@coldLinesPoint.include?(citems[0])
    			@coldLinesPoint << citems[1] if !@coldLinesPoint.include?(citems[1])
    		}
    		if @hotDevicePointList.length >= 2
    			get_coldorhot_link_points(@hotDevicePointList,"hot",high)
    		end 
    		@hotLines = stand_against_wall(@hotLines)

            #为确保线段表示最优，再做次细分
            @hotLines = refine_lines(@hotLines)

    		@hotLines.each{|hitems|
    			@hotLinesPoint << hitems[0] if !@hotLinesPoint.include?(hitems[0])
    			@hotLinesPoint << hitems[1] if !@hotLinesPoint.include?(hitems[1])
    		}
            
            #画在组内
            @lineGroupEnt = @ents.add_group.entities
    		draw_line_by_segments(@coldLines,"cold")
    		draw_line_by_segments(@hotLines,"hot")
    		
    		#标管径
    		@segmentDiameterHash = {} #线段-管径 哈希数据
    		if @coldLines.size > 0
    		    draw_pipe_diameter("cold")
    		end 
    		if @hotLines.size > 0
    			draw_pipe_diameter("hot")
    		end 
    		# #将管径写进线段属性中
    		@segmentDiameterHash.each{|key,value|
    			#找到key对应的Edge实体
    			edgeEnt = find_edge_ent_by_segment(key,@lineGroupEnt)
    			edgeEnt.set_attribute('attributedictionaryname', 'pipeDiameter', "#{value}") if edgeEnt != 0
    		}
        rescue Exception => e 

        ensure 
            #删除@wallFaceListRel
            delEdges = []
            @wallFaceListRel.each{|item|
                item.edges.each{|item2|
                    delEdges << item2 if !delEdges.include?(item2)
                }
            }
            delEdges.each{|item|
                begin
                    item.erase!
                rescue Exception => ex 
                    # p ex.message
                    next
                end 
            }
        end 

		@model.commit_operation 
		
    end

    #找到segment对应的Edge实体
    def find_edge_ent_by_segment(segment,ent)
    	edgeRst = 0
    	if segment.size == 2
    		position1 = Geom::Point3d.new(segment[0])
    		position2 = Geom::Point3d.new(segment[1])
	    	ent.each{|item|
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
	
	#将立管靠墙
	def stand_against_wall(segments)
		if segments == @coldLines
			devicePointList = @coldDevicePointList
		elsif segments == @hotLines
			devicePointList = @hotDevicePointList
		end 
		segments = refine_lines(segments)
		segments_c = segments.clone
		
		segments_c.each{|items|
			itemsFlag = false #是否是立管的标志
			devicePoint = 0 #设备靠墙点
			otherPoint = 0
			devicePointList.each{|pItem|
				if items.include?(pItem)
					itemsFlag = true
					devicePoint = pItem
					otherPoint = items[1] if items[0] == pItem
					otherPoint = items[0] if items[1] == pItem
					break
				end 
			}
			if itemsFlag
				device = @pointEntHash[devicePoint]
				if !@allDeviceClosestResult[device].nil?
					vecToWall = @allDeviceClosestResult[device].last
					#找出后一线段，看其方向是否与vecToWall一致，若是则合并
					flag2 = false #默认不是
					if otherPoint != 0 
						vec_other = 0
						otherPoint2 = 0
						otherSegment = 0
						count = count_point_in_segments(otherPoint,segments_c)
						segments_c.each{|items2|
							if items2 != items && items2.include?(otherPoint)
								otherPoint2 = items2[1] if items2[0] == otherPoint
								otherPoint2 = items2[0] if items2[1] == otherPoint
								vec_other = Geom::Vector3d.new(otherPoint2[0]-otherPoint[0],otherPoint2[1]-otherPoint[1],otherPoint2[2]-otherPoint[2])
								otherSegment = items2


								if vec_other != 0
									if judge_two_vectors_parallel(vec_other,vecToWall) 
										flag2 = true #是否垂直与墙的标志
									end
									
									point_vi1 = get_point_move_by_vector(items[0],vecToWall)
									point_vi2 = get_point_move_by_vector(items[1],vecToWall)
									if items[0][2] < items[1][2]
										segment1 = [items[0], point_vi1]
										segment2 = [point_vi1, point_vi2]
										pointList = [otherPoint2, otherPoint, point_vi1]
									else
										segment1 = [items[1], point_vi2]
										segment2 = [point_vi2, point_vi1]
										pointList = [otherPoint2, otherPoint, point_vi2]
									end 
									if flag2 && count < 3
										points = combinate_point_path(pointList)
										segments.delete(otherSegment)
										segments << [points[0], points[1]] if points.size == 2
									else
										segments << segment1
									end 
									segments << segment2
									segments.delete(items)
									
								end 
							end 
						}

					end 
				

				end 
			end 
		}
		segments
	end 

    #判断两向量是否平行,因为可能有误差，导致不一定是0度或180
    def judge_two_vectors_parallel(vec1,vec2)
        flag = false
        if vec1.angle_between(vec2).abs < 0.1 || (vec1.angle_between(vec2) - 3.14).abs < 0.1
            flag = true
        end 
        flag
    end 


	#管线偏移至离墙距离distanceFromWall(150.mm)
    def pipeline_migrate_distance_from_wall(points, distanceFromWall, type)
        changedpointList = []
        points.each_cons(2){|pitems|
            #只有当两点在同一水平面时才考虑穿墙问题
            if pitems[0][2] == pitems[1][2]
                vec = Geom::Vector3d.new(pitems[1][0]-pitems[0][0],pitems[1][1]-pitems[0][1],pitems[1][2]-pitems[0][2])
                line = [pitems[0],vec]   

                @wallFaceListRel.each{|item|
                    if item.typename == "Face"
                        if (item.normal.dot(vec)).abs < 0.1  #只管线段与墙面平行的，垂直的不管
                            distance = distance_from_segement_to_face([pitems[0],pitems[1]], item)
                            if distance > 0.1.mm && distance < distanceFromWall
                                distoff = distanceFromWall - distance
                                if  judge_two_vectors_parallel(vec, @vec_l)         
                                    pitems0_vi = [pitems[0][0] + @vec_w_xleng*distoff, pitems[0][1] + @vec_w_yleng*distoff, pitems[0][2] + @vec_w_zleng*distoff]
                                    pitems1_vi = [pitems[1][0] + @vec_w_xleng*distoff, pitems[1][1] + @vec_w_yleng*distoff, pitems[1][2] + @vec_w_zleng*distoff]
                                    distance_vi = distance_from_segement_to_face([pitems0_vi,pitems1_vi], item)
                                    
                                    #移动后点和原来端点在墙的同一边
                                    line2 = [pitems[0],item.normal]
                                    plane = [item.vertices[0].position,item.normal]
                                    point_ins = Geom.intersect_line_plane(line2, plane)
                                    
                                    vecpp = Geom::Vector3d.new(point_ins[0]-pitems[0][0],point_ins[1]-pitems[0][1],point_ins[2]-pitems[0][2])
                                    vecpp_vi = Geom::Vector3d.new(point_ins[0]-pitems0_vi[0],point_ins[1]-pitems0_vi[1],point_ins[2]-pitems0_vi[2])

                                    #管线不能重合 
                                    if type == "hot"
                                        flag = false
                                        @coldLinesPoint.each{|item2|
                                            flag = judge_point_in_segment(item2,pitems0_vi,pitems1_vi)
                                            break if flag 
                                        }
                                        if !flag
                                            @coldLines.each{|items|
                                                flag2, flag3 = false, false
                                                flag2 = judge_point_in_segment(pitems0_vi,items[0],items[1])
                                                flag3 = judge_point_in_segment(pitems1_vi,items[0],items[1])
                                                if flag2 || flag3
                                                    flag = true
                                                    break
                                                end 
                                            }
                                            end
                                        if flag
                                            pitems0_vi = [pitems[0][0] + @vec_w_xleng*(distoff+distanceFromWall), pitems[0][1] + @vec_w_yleng*(distoff+distanceFromWall), pitems[0][2] + @vec_w_zleng*(distoff+distanceFromWall)]
                                            pitems1_vi = [pitems[1][0] + @vec_w_xleng*(distoff+distanceFromWall), pitems[1][1] + @vec_w_yleng*(distoff+distanceFromWall), pitems[1][2] + @vec_w_zleng*(distoff+distanceFromWall)]
                                        end 
                                    end
                                    if vecpp.length > 1.mm && vecpp_vi.length > 1.mm
                                        if !vecpp.samedirection?(vecpp_vi) || (vecpp.samedirection?(vecpp_vi) && distance_vi < distance)
                                            pitems0_vi = [pitems[0][0] - @vec_w_xleng*distoff, pitems[0][1] - @vec_w_yleng*distoff, pitems[0][2] - @vec_w_zleng*distoff]
                                            pitems1_vi = [pitems[1][0] - @vec_w_xleng*distoff, pitems[1][1] - @vec_w_yleng*distoff, pitems[1][2] - @vec_w_zleng*distoff]
                                            #管线不能重合
                                            if type == "hot"
                                                flag = false
                                                @coldLinesPoint.each{|item2|
                                                    flag = judge_point_in_segment(item2,pitems0_vi,pitems1_vi)
                                                    break if flag
                                                }
                                                if !flag
                                                    @coldLines.each{|items|
                                                        flag2, flag3 = false, false
                                                        flag2 = judge_point_in_segment(pitems0_vi,items[0],items[1])
                                                        flag3 = judge_point_in_segment(pitems1_vi,items[0],items[1])
                                                        if flag2 || flag3
                                                            flag = true
                                                            break
                                                        end 
                                                    }
                                                end
                                                if flag
                                                    pitems0_vi = [pitems[0][0] - @vec_w_xleng*(distoff+distanceFromWall), pitems[0][1] - @vec_w_yleng*(distoff+distanceFromWall), pitems[0][2] - @vec_w_zleng*(distoff+distanceFromWall)]
                                                    pitems1_vi = [pitems[1][0] - @vec_w_xleng*(distoff+distanceFromWall), pitems[1][1] - @vec_w_yleng*(distoff+distanceFromWall), pitems[1][2] - @vec_w_zleng*(distoff+distanceFromWall)]
                                                end 
                                            end
                                        end 
                                    end
                                else
                                    pitems0_vi = [pitems[0][0] + @vec_l_xleng*distoff, pitems[0][1] + @vec_l_yleng*distoff, pitems[0][2] + @vec_l_zleng*distoff]
                                    pitems1_vi = [pitems[1][0] + @vec_l_xleng*distoff, pitems[1][1] + @vec_l_yleng*distoff, pitems[1][2] + @vec_l_zleng*distoff]
                                    distance_vi = distance_from_segement_to_face([pitems0_vi,pitems1_vi], item)
                                    
                                    #移动后点和原来端点在墙的同一边
                                    line2 = [pitems[0],item.normal]
                                    plane = [item.vertices[0].position,item.normal]
                                    point_ins = Geom.intersect_line_plane(line2, plane)
                                    vecpp = Geom::Vector3d.new(point_ins[0]-pitems[0][0],point_ins[1]-pitems[0][1],point_ins[2]-pitems[0][2])
                                    vecpp_vi = Geom::Vector3d.new(point_ins[0]-pitems0_vi[0],point_ins[1]-pitems0_vi[1],point_ins[2]-pitems0_vi[2])

                                    #管线不能重合
                                    if type == "hot"
                                        flag = false
                                        @coldLinesPoint.each{|item2|
                                            flag = judge_point_in_segment(item2,pitems0_vi,pitems1_vi)
                                            break if flag 
                                        }
                                        if !flag
                                            @coldLines.each{|items|
                                                flag2, flag3 = false, false
                                                flag2 = judge_point_in_segment(pitems0_vi,items[0],items[1])
                                                flag3 = judge_point_in_segment(pitems1_vi,items[0],items[1])
                                                if flag2 || flag3
                                                    flag = true
                                                    break
                                                end 
                                            }
                                        end
                                        if flag
                                            pitems0_vi = [pitems[0][0] + @vec_l_xleng*(distoff+distanceFromWall), pitems[0][1] + @vec_l_yleng*(distoff+distanceFromWall), pitems[0][2] + @vec_l_zleng*(distoff+distanceFromWall)]
                                            pitems1_vi = [pitems[1][0] + @vec_l_xleng*(distoff+distanceFromWall), pitems[1][1] + @vec_l_yleng*(distoff+distanceFromWall), pitems[1][2] + @vec_l_zleng*(distoff+distanceFromWall)]
                                        end 
                                    end
                                    if vecpp.length > 1.mm && vecpp_vi.length > 1.mm
                                        if !vecpp.samedirection?(vecpp_vi) || (vecpp.samedirection?(vecpp_vi) && distance_vi < distance)
                                            pitems0_vi = [pitems[0][0] - @vec_l_xleng*distoff, pitems[0][1] - @vec_l_yleng*distoff, pitems[0][2] - @vec_l_zleng*distoff]
                                            pitems1_vi = [pitems[1][0] - @vec_l_xleng*distoff, pitems[1][1] - @vec_l_yleng*distoff, pitems[1][2] - @vec_l_zleng*distoff]
                                            #管线不能重合
                                            if type == "hot"
                                                flag = false
                                                @coldLinesPoint.each{|item2|
                                                    flag = judge_point_in_segment(item2,pitems0_vi,pitems1_vi)
                                                    break if flag 
                                                }
                                                if !flag
                                                    @coldLines.each{|items|
                                                        flag2, flag3 = false, false
                                                        flag2 = judge_point_in_segment(pitems0_vi,items[0],items[1])
                                                        flag3 = judge_point_in_segment(pitems1_vi,items[0],items[1])
                                                        if flag2 || flag3
                                                            flag = true
                                                            break
                                                        end 
                                                    }
                                                end
                                                if flag
                                                    pitems0_vi = [pitems[0][0] - @vec_l_xleng*(distoff+distanceFromWall), pitems[0][1] - @vec_l_yleng*(distoff+distanceFromWall), pitems[0][2] - @vec_l_zleng*(distoff+distanceFromWall)]
                                                    pitems1_vi = [pitems[1][0] - @vec_l_xleng*(distoff+distanceFromWall), pitems[1][1] - @vec_l_yleng*(distoff+distanceFromWall), pitems[1][2] - @vec_l_zleng*(distoff+distanceFromWall)]
                                                end 
                                            end
                                        end 
                                    end
                                end

                                #坐标替换
                                if !changedpointList.include?(pitems[0]) && !changedpointList.include?(pitems[1])
                                    changedpointList << pitems[0]
                                    changedpointList << pitems[1]
                                    points.each{|pitem|
                                        offset = points.index(pitem)
                                        if (pitem.distance pitems[0]) < 1.mm
                                            points.delete_at(offset) 
                                            points.insert(offset,pitems0_vi)
                                        elsif (pitem.distance pitems[1]) < 1.mm
                                            points.delete_at(offset) 
                                            points.insert(offset,pitems1_vi)
                                        end
                                    }
                                else
                                    pipeline_migrate_distance_from_wall(points, distanceFromWall,type)
                                end
                            end 
                        end
                    end
                }
             
            end # 只考虑同一水平面的 end 
        }
        points
    end 

    #判断一个点是否是洁具下的点
    def judge_point_is_link_device(point)
        flag = false
        @pointEntHash.each{|key,value|
            if point[0] == key[0] && point[1] == key[1]
                flag = true
                break
            end
        }
        flag
    end 


    #线段到平面的距离(平行)
    def distance_from_segement_to_face(segment, face)
        vec = Geom::Vector3d.new(segment[1][0]-segment[0][0],segment[1][1]-segment[0][1],segment[1][2]-segment[0][2])
        sline = [segment[0],vec]
        distance = 0
        if vec.length > 0.1.mm && face.normal.length > 0.1.mm && face.normal.dot(vec) < 0.1.mm 
            pointCenter = Geom.linear_combination(0.5,segment[0],0.5,segment[1])
            line2 = [pointCenter,face.normal]
            plane = [face.vertices[0].position,face.normal]
            point_ins = Geom.intersect_line_plane(line2, plane)
            line3 = [segment[0],face.normal]
            point_ins_2 = Geom.intersect_line_plane(line3, plane)
            line4 = [segment[1],face.normal]
            point_ins_3 = Geom.intersect_line_plane(line4, plane)
            leftPointCenter = Geom.linear_combination(0.25,segment[0],0.75,segment[1])
            line5 = [leftPointCenter,face.normal]
            point_ins_4 = Geom.intersect_line_plane(line5, plane)
            rightPointCenter = Geom.linear_combination(0.75,segment[0],0.25,segment[1])
            line6 = [rightPointCenter,face.normal]
            point_ins_5 = Geom.intersect_line_plane(line6, plane)

            wallpoint = face.vertices[0].position
            #取平面端点（和线同一高度）
            wallpoint = [wallpoint[0],wallpoint[1],segment[0][2]]
            linewall = [wallpoint,face.normal]
            point_ins_wall = Geom.intersect_line_line(sline,linewall)
            if face.classify_point(point_ins) == 1 || face.classify_point(point_ins) == 2 || face.classify_point(point_ins) == 4
                distance = pointCenter.distance point_ins
            elsif face.classify_point(point_ins_2) == 1 || face.classify_point(point_ins_2) == 2 || face.classify_point(point_ins_2) == 4
                distance = segment[0].distance point_ins_2
            elsif face.classify_point(point_ins_3) == 1 || face.classify_point(point_ins_3) == 2 || face.classify_point(point_ins_3) == 4
                distance = segment[1].distance point_ins_3
            elsif face.classify_point(point_ins_4) == 1 || face.classify_point(point_ins_4) == 2 || face.classify_point(point_ins_4) == 4
                distance = leftPointCenter.distance point_ins_4
            elsif face.classify_point(point_ins_5) == 1 || face.classify_point(point_ins_5) == 2 || face.classify_point(point_ins_5) == 4
                distance = rightPointCenter.distance point_ins_5
            elsif !point_ins_wall.nil? 
                flag = judge_point_in_segment(point_ins_wall,segment[0],segment[1])
                distance = point_ins_wall.distance(wallpoint) if flag
            end
        end
        distance
    end 

	
	#替换线段列中的某点(segments中的point1换成point2)
	def replace_point_in_segments(point1,point2,segments)
		segments_new = []
		if segments.size > 0
			segments.each{|items|
				if items[0] == point1
					items[0] = point2
				elsif items[1] == point1
					items[1] == point2
				end 
				segments_new << items
			}
		end 
		segments_new
	end 
	
	#点沿着向量移动后stepLength单位后的点,默认为向量长
    def get_point_move_by_vector(point,vec,stepLength = [0,0,0].distance(Geom::Point3d.new(vec)))
        if !point.nil? 
            point_new = point.clone
            vec_leng = [0,0,0].distance([vec[0],vec[1],vec[2]])
            vec_xleng = vec[0]/vec_leng
            vec_yleng = vec[1]/vec_leng
            vec_zleng = vec[2]/vec_leng
            point_new = [point[0] + vec_xleng*(stepLength), point[1] + vec_yleng*(stepLength),point[2] + vec_zleng*(stepLength)]
        else
            point_new = 0
        end 
        point_new
    end 
	
	
	#找出墙面
	def find_wall_faces
		wallFaceList = []
		@attributeHashList.each{|item|
				if item["name"].to_s == "墙"  #
					if item["ent"].typename == "Group"
						item["ent"].entities.each{|item2|
							if item2.typename == "Face" && !item2.normal.samedirection?([0,0,1]) && !item2.normal.samedirection?([0,0,-1])
								wallFaceList << item2 if !wallFaceList.include?(item2)
							end 
						}	
					elsif item["ent"].typename == "ComponentInstance"
						item["ent"].definition.entities.each{|item2|
							if item2.typename == "Face" && !item2.samedirection?([0,0,1]) && !item2.samedirection?([0,0,-1])
								wallFaceList << item2 if !wallFaceList.include?(item2)
							end 
						}	
					end
				end
			}
		wallFaceList
	end 

    def find_wall_faces_2
        wallFaceList = []
        if @groupList.size > 0
            @groupList.each{|item|
                value = item.get_attribute('DFC_结构', '类别', 0)
                if value.to_s.include?("墙")
                    item.entities.each{|item2|
                        if item2.typename == "Face"
                            wallFaceList << item2 if !wallFaceList.include?(item2)
                        end 
                    }
                end
            }
        end
        if  @instanceList.size > 0
             @instanceList.each{|item|
                value = item.get_attribute('DFC_结构', '类别', 0)
                if value.to_s.include?("墙")
                    item.entities.each{|item2|
                        if item2.typename == "Face"
                            wallFaceList << item2 if !wallFaceList.include?(item2)
                        end 
                    }
                end
            }
        end 

        wallFaceList
    end 

	
	#在限定的距离内找出最近的墙面
	def get_closest_wallFace_result(point,wallFaceListRel,limitedDistance)
		resultList = [] #结果，point，交点point_int ,距离 , point到交点的向量
		distance_min = limitedDistance #默认最大的最近距离
		wallFaceListRel.each{|wItem|
			item2point0 = wItem.vertices[0].position
			plane = [item2point0, Geom::Vector3d.new(wItem.normal)]
			line = [point, wItem.normal]
			point_int = Geom.intersect_line_plane(line, plane)
			if !point_int.nil?
				#距离
				point_int = [point_int[0],point_int[1],point_int[2]]
				distancew = point.distance point_int
				#限定距离内的墙面才处理，否则不管
				if distancew <= limitedDistance
					#交点在墙上
					if wItem.classify_point(point_int) == 1 || wItem.classify_point(point_int) == 2 || wItem.classify_point(point_int) == 4
						#保存距离和point到交点的向量
						if distancew <= distance_min
							distance_min = distancew
							vec = [point_int[0]-point[0],point_int[1]-point[1],point_int[2]-point[2]]
							resultList = [point, point_int, distancew, vec ]
						end 
					end
				end 
			end
		}
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
		
		point1Vertex = find_vertex_by_point(point1,@lineGroupEnt)
		allRoutelist = get_link_vertex_edges(point1Vertex)
		#设置最大线段数为100
		(0..98).each{|count|
			# p "count: #{count}"
			#第count+2步（即最长线段数为count+2）
			allRoutelist = get_link_routes_edges(allRoutelist,count)
		}

		all_num = allRoutelist.size
        
		allRoutelist_c = allRoutelist.clone
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
		point2Vertex = find_vertex_by_point(point2,@lineGroupEnt)
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
				alledges << list 
			}
		end
		alledges
	end

	
	#根据坐标来找端点(vertex类型)
	def find_vertex_by_point(point,ent)
		vertex = 0
		ent.each{|item|
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
								routeNum3 = routes.length
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

	#判断两直线段是否有交点
	def judge_intersec_point_by_segments(segment1,segment2)
		flag = false
		flag1 = judge_point_in_segment(segment1[0],segment2[0],segment2[1])
		flag2 = judge_point_in_segment(segment1[1],segment2[0],segment2[1])
		flag3 = judge_point_in_segment(segment2[0],segment1[0],segment1[1])
		flag4 = judge_point_in_segment(segment2[1],segment1[0],segment1[1])
		if flag1 || flag2 || flag3 || flag4
			flag = true
		else
			vec1 = Geom::Vector3d.new(segment1[1][0]-segment1[0][0], segment1[1][1]-segment1[0][1], segment1[1][2]-segment1[0][2])
			vec2 = Geom::Vector3d.new(segment2[1][0]-segment2[0][0], segment2[1][1]-segment2[0][1], segment2[1][2]-segment2[0][2])
			#不同向
			if vec1.length > 2.mm && vec2.length > 2.mm && !vec1.samedirection?(vec2) && !vec1.reverse.samedirection?(vec2)
				line1 = [segment1[0],Geom::Vector3d.new(vec1)] 
				line2 = [segment2[0],Geom::Vector3d.new(vec2)]
				intersectPoint = Geom.intersect_line_line(line1,line2)
				if !intersectPoint.nil?
					ds1 = segment1[1].distance segment1[0]
					ds2 = segment2[1].distance segment2[0]
					
					dints10 = intersectPoint.distance segment1[0]
					dints11 = intersectPoint.distance segment1[1]
					dints20 = intersectPoint.distance segment2[0]
					dints21 = intersectPoint.distance segment2[1]
					flag = true if dints10 <= ds1 && dints11 <= ds1 && dints20 <= ds2 && dints21 <= ds2
				end
			end
		end
		flag
	end 
	
	
	#获得水管连线点
	def get_coldorhot_link_points(points, type, high)
		points_c = points.clone #先克隆一份，免得修改了实例变量
		mainLinePointList = [] #保存主线两点
		if type == "cold"
			mainLinePointList << @startPoint
		elsif type == "hot"
            # p "开始连接热水管"
			# mainLinePointList << find_distance_closest_point(@startPoint,points_c)
            #找热水器，将热水器作为热水的给水点
            points_c.each{|item|
                @pointEntHash.each{|key,value|
                    if (item.distance key) < 0.1 && value["name"].include?("热水器")
                        break if mainLinePointList.length > 0
                        mainLinePointList << item
                    end 
                }
            }
		end
		#主线另外一点
		mainLinePointList << find_distance_max_point(mainLinePointList[0],points_c)
		#将主线连上并保存记录每条线段
		@lineList = [] #所有管道
		
		mainLinePointList.each_cons(2){|item|
			pointList = []
			if type == "cold"
                begin
                    timeout(10) do 
                        pointList = get_link_point(item[0],item[1],type,high)
                    end
                rescue Exception => e 
                    # p "11111111"
                end
				pointList = get_link_point_2(item[0],item[1],type,high) if pointList.size == 0
			elsif type == "hot"
                begin
                    timeout(10) do 
                        pointList = get_link_point(item[0],item[1],type,high)
                    end
                rescue Exception => e 
                    # p "22222222"
                end
                pointList = get_link_point_2(item[0],item[1],type,high) if pointList.size == 0
			end
			if pointList.size > 0 #连的上
                # p "主管已连上"
				#设置离墙距离
				pointList = pipeline_migrate_distance_from_wall(pointList,150.mm,type)
				pointList.each_cons(2){|item|
					#线段去重
					temp_list = []
					temp_list = remove_repeat_segment(item[0],item[1],@lineList)
					
					if temp_list != [0,0]	#有新增线段 
						if type == "cold"
							@coldmainlineList << temp_list 
						elsif type == "hot"
							@hotmainlineList << temp_list 
						end 
						@lineList << temp_list 
					end
				}
            else
                # p "主管没连上"
			end
		}	

		#连接剩余点
		points_c.each{|item|
			points_c.delete(item) if mainLinePointList.include?(item)
		}

        #将剩余点按序排列(离主线两点中心点越近的越先连)
        mainCenterPoint = Geom.linear_combination(0.5,mainLinePointList[0],0.5,mainLinePointList[1])
        disPointhash = {}
        points_c.each{|item|
            disItem = item.distance mainCenterPoint
            disPointhash[disItem] = item
        }
        disList = disPointhash.keys.sort()
        points_c_c = []
        disList.each{|item|
            points_c_c << disPointhash[item]
        }
        points_c = points_c_c
		points_c.each{|item|
			# if @devicePropertysNameList.include?(@pointEntHash[item]["name"])
			# 	pipeDiameter = @devicePropertys[@pointEntHash[item]["name"]]["pipeDiameter"]
			# end 
			if type == "cold"
				point_vi = [item[0],item[1],@zCoordinate+high]
			elsif type == "hot"
				point_vi = [item[0],item[1],@zCoordinate+high]
			end
			
			dpfList = [] #哈希保存距离、交点及是否在线段外 0直线内，1直线外
			#遍历线段
			@lineList.each{|item2s|
				#水平面段
				if item2s[0][2] == item2s[1][2] && (item2s[0][0] != item2s[1][0] || item2s[0][1] != item2s[1][1])
					distance12s = item2s[0].distance item2s[1]
					#过点做垂线，记录垂线段长度
					line1 = [item2s[0], Geom::Point3d.new(item2s[1])]
					vec1 = [item2s[1][0]-item2s[0][0], item2s[1][1]-item2s[0][1], item2s[1][2]-item2s[0][2]]
					
					if (vec1.dot @vec_l).abs <= 0.1
						line2 = [point_vi, Geom::Vector3d.new(@vec_l)]
					elsif (vec1.dot @vec_w).abs <= 0.1
						line2 = [point_vi, Geom::Vector3d.new(@vec_w)]
					end
					
					point_int = Geom.intersect_line_line(line1,line2) if !line1.nil? && !line2.nil?
					if !point_int.nil?
						point_int = [point_int[0],point_int[1],@zCoordinate+high]
						if point_int == point_vi
							distance_vi1 = item2s[0].distance point_int
							distance_vi2 = item2s[1].distance point_int
							#比较离哪个端点近
							if distance_vi1 < distance_vi2
								dpfList << [distance_vi1,item2s[0],0] if item2s[0] != @startPoint
							else
								dpfList << [distance_vi2,item2s[1],0] if item2s[1] != @startPoint
							end
						else
							distance_it_in = point_vi.distance point_int
							distance_vi1 = item2s[0].distance point_int
							distance_vi2 = item2s[1].distance point_int
							#交点在在线段内
							if distance_vi1 <= distance12s && distance_vi2 <= distance12s
								dpfList << [distance_it_in,point_int,0]
							else#交点在线段外
								#比较离哪个端点近
								if distance_vi1 < distance_vi2
									distance_it_in = distance_it_in + distance_vi1
									dpfList << [distance_it_in,point_int,1,item2s[0]] if item2s[0] != @startPoint
								else
									distance_it_in = distance_it_in + distance_vi2
									dpfList << [distance_it_in,point_int,1,item2s[1]] if item2s[1] != @startPoint
								end
							end
						end
					else
						# p "交点为nil"*10
					end
				end
			}

			#1直接遍历dpfList，取距离最小的，有点：耗时较少.缺陷：不是最短，且有时会连不上
			if dpfList.size > 0 
                #将dpfList按从近到远排序
                dpfList = dpfList.sort_by{|v| v[0]}

                #因为已排好序，故从头开始遍历，若连上则取消遍历即可
                distanceSegmentList = [] #所有线段列的长度，取最短。缺陷：耗时长. 优点:结果准确。
                dpfList.each{|item2|
                    pointlast = item2[1]
                    pointlast = item2[3] if item2[2] == 1
                    pointList = []
                    pointList << item
                    pointList2 = []
                    if type == "cold"
                        begin 
                            timeout(10) do 
                                pointList2 = get_link_point(point_vi,pointlast,type,high)
                            end 
                        rescue Exception => e 
                            # p "3333333"
                        end 
                    elsif type == "hot"
                        begin 
                            timeout(10) do
                                pointList2 = get_link_point(point_vi,pointlast,type,high)
                            end 
                        rescue Exception => e 
                            # p "4444444"
                        end 
                    end
                    if pointList2.size == 0
                        begin 
                            timeout(10) do 
                                pointList2 = get_link_point_2(point_vi,pointlast,type,high) 
                            end
                        rescue Exception => e 
                            # p e.message
                            # p "55555555"*5
                        end 
                    end 
                    # next if pointList2.size == 0
                    if pointList2.size > 0 #为0说明被围了，连不上
                        pointList2 = pipeline_migrate_distance_from_wall(pointList2,150.mm,type)
                        pointList.concat(pointList2)
                        distan = 0
                        list_item2 = []
                        pointList.each_cons(2){|pitem|
                            #线段去重
                            temp_list = []
                            temp_list = remove_repeat_segment(pitem[0],pitem[1],@lineList)
                            if temp_list != [0,0]   #有新增线段 
                                #保存计算所有线段的总长度
                                distan += temp_list[0].distance temp_list[1]
                                list_item2 << temp_list
                            end
                        }
                        distanceSegmentList << [distan,list_item2]
                        #不遍历distanceSegmentList
                        list_item2.each{|items2|
                            @lineList << items2
                            # if type == "cold"
                            #     @coldbrancheshash[item] = [] if @coldbrancheshash[item].nil?
                            #     @coldbrancheshash[item] << [items2[0], items2[1]]
                            # end
                        }
                        break
                    end
                }
			end
		}

		if type == "cold"
			@coldLines = @lineList
		elsif type == "hot"
			@hotLines = @lineList
		end
	end 

	
	#标管径
	def draw_pipe_diameter(type)
		if type == "cold"
			startPoint = @startPoint
			lines = @coldLines
			devicePointList = @coldAllowWallPointList
			linesPoint = @coldLinesPoint
		elsif type == "hot"
            #热水器对应到墙上的点
            @hotAllowWallPointList.each{|item|
                @pointEntHash.each{|key,value|
                    if (item.distance key) < 0.1 && value["name"].include?("热水器")
                        startPoint = item
                        break
                    end 
                }
            }
			# startPoint = @hotAllowWallPointList[0] 
            # p "startPoint : "
            # show_mm_points([startPoint])
			lines = @hotLines
			devicePointList = @hotAllowWallPointList
			linesPoint = @hotLinesPoint	
		end
		draw_pipe_diameter_common(startPoint,lines,devicePointList,linesPoint,type)
	end 
	
	def draw_pipe_diameter_common(startPoint,lines,devicePointList,linesPoint,type)
		#从各个设备点往给水点走，每经过一端点，该端点分支数+1 （树节点模型）
		pointBranceCountHash = {}
		#先将@coldLines细化，如：两线段有交点的应该改为多个线段
		segmentList = []
		segmentList = refine_lines(lines)
		#开始遍历设备点
		allBranceRoutePoins = [] #所有路线点集的数组
		devicePointList.each{|item|
			vertexs = []
            if type != "hot" || item != startPoint
    			vertexs = find_shortest_segments_with_two_points(item,startPoint,segmentList)
    			allBranceRoutePoins << change_vertexs_to_points(vertexs)
            end
		}
		if allBranceRoutePoins.length > 0
            @flowingEquipmentHash = {}
			allBranceRoutePoins.each{|items|
				items.each{|item|
					if pointBranceCountHash[item].nil?
						pointBranceCountHash[item] = 1
					else
						pointBranceCountHash[item] += 1 
					end
                    #并记录每一端点所负担的洁具
                    if @flowingEquipmentHash[item].nil?
                        @flowingEquipmentHash[item] = []
                        @flowingEquipmentHash[item] << items[0]
                    else
                        @flowingEquipmentHash[item] << items[0]
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
			#端点处标记龙头个数
			# p "pointBranceCountHash: #{pointBranceCountHash}"
			# linesPoint.each{|item|
			# 	pointBranceCountHash.each{|key,value|
			# 		if (item.distance key) < 1.mm
			# 			@ents.add_text "#{pointBranceCountHash[key]}", item
			# 			break
			# 		end
			# 	}
			# }
			#取线段两端点标记的龙头个数较小的那个，再据此决定管径大小
			# segmentList.each{|items|
			# 	pointCenter = Geom.linear_combination(0.5, items[0], 0.5, items[1])
			# 	num1 = 1
			# 	num2 = 1
			# 	pointBranceCountHash.each{|key,value|
			# 		if (items[0].distance key) < 1.mm
			# 			num1 = pointBranceCountHash[key]
			# 			break
			# 		end
			# 	}
			# 	pointBranceCountHash.each{|key,value|
			# 		if (items[1].distance key) < 1.mm
			# 			num2 = pointBranceCountHash[key]
			# 			break
			# 		end
			# 	}
			# 	num_min = num1 <= num2 ? num1 : num2
			# 	@ents.add_text "#{@pipeDiameterHash_new["#{num_min}"]}", pointCenter
			# 	@segmentDiameterHash[items] = @pipeDiameterHash_new["#{num_min}"]
			# }
     
            #具体计算各端点管径
            pointPipeDnHash = {}  #端点处管径
            linesPoint.each{|item|
                pipeDiameter = 0
                pointBranceCountHash.each{|key,value|
                    if (item.distance key) < 1.mm
                        # p "pointBranceCountHash[key] : #{pointBranceCountHash[key].to_i}"
                        if pointBranceCountHash[key].to_i > 1
                            pipeDiameterResult = calculate_pipe_diameter(key,@personNum,@kh,@dql,@useTime,@pipeMaterialType)
                            pipeDiameter = pipeDiameterResult[0]
                            if pipeDiameter != 0
                                # @ents.add_text "DN#{pipeDiameter}", item
                                pointPipeDnHash[item] = pipeDiameter
                            else
                                p "未知管径端点 item11111 :"
                                show_mm_points([item])
                            end
                        else
                            #只承接一个器具的按表写管径
                              # @pointEntHash   @flowingEquipmentHash
                            devicePoint = 0
                            @flowingEquipmentHash.each{|key2,value2|
                                if (key2.distance key) < 0.1
                                    devicePoint = value2[0]
                                    break
                                end 
                            }
                            deviceName = 0
                            supplyFittingName = 0
                            deviceQl = 0
                            @pointEntHash.each{|key3,value3|
                                if (key3.distance devicePoint) < 0.1
                                    device = value3
                                    deviceName = device["name"].delete(" ")
                                    supplyFittingName = device["supplyFittingName"].delete(" ")
                                    deviceQl = device["ql"]

                                end 
                            }
                            
                            # p "supplyFittingName: #{supplyFittingName}"
                            # p "deviceQl : #{deviceQl}"
                            #根据deviceName 、supplyFittingName、 deviceQl确定管径
                            qlScope = [] #额定流量范围  或 “ ，”
                            @supplyFitInfoHash.each{|key4,value4|
                                if key4.delete(" ") == "未知器具" || key4.delete(" ").include?(deviceName)
                                    value4.each{|vItem|
                                        if vItem[0].delete(" ") ==  supplyFittingName 
                                            if vItem[1].include?("~")
                                                qlScope = vItem[1].split("~") #区间
                                                #判断是否在该区间
                                                if qlScope[0].delete(" ").to_f <= deviceQl || qlScope[1].delete(" ").to_f >= deviceQl
                                                    #在则取管径
                                                    pipeDiameter = vItem[3]
                                                    break
                                                end 
                                            elsif vItem[1].include?("(")
                                                lis = []
                                                lis = vItem[1].split("(")
                                                ql1 = lis[0][/\d+\.*\d*/].to_f
                                                ql2 = lis[1][/\d+\.*\d*/].to_f
                                                if ql1 == deviceQl || ql2 == deviceQl
                                                    pipeDiameter = vItem[3]
                                                    break
                                                end 
                                            elsif deviceQl == vItem[1].to_f
                                                pipeDiameter = vItem[3]
                                                break
                                            end 

                                        end 
                                    }
                                end 
                                break if pipeDiameter != 0 
                            }
                            if pipeDiameter == 0
                                p "未知管径端点 item2222 :"
                                show_mm_points([item])
                            else
                                # @ents.add_text "DN#{pipeDiameter}", item
                                pointPipeDnHash[item] = pipeDiameter
                            end
                            
                        end 
                        break
                    end  # end if (item.distance key)

                }
            }

            #线段管径写属性  pointPipeDnHash
            segmentList.each{|items|
                pointCenter = Geom.linear_combination(0.5, items[0], 0.5, items[1])
                num1 = 0
                num2 = 0
                pointPipeDnHash.each{|key,value|
                    if (items[0].distance key) < 1.mm
                        num1 = value.to_i
                        break
                    end 
                }
                pointPipeDnHash.each{|key,value|
                    if (items[1].distance key) < 1.mm
                        num2 = value.to_i
                        break
                    end 
                }
                num_min = num1 <= num2 ? num1 : num2
                @lineGroupEnt.add_text "DN#{num_min}", pointCenter
                @segmentDiameterHash[items] = "DN#{num_min}"
            }
		end
	end 
	
    #具体计算每一管道端点的管径 参数：personNum:人数, kh:小时变化系数, ql:最高用水日的用水定额, t: 小时数, pipeMaterialType: 水管材料类型
	def calculate_pipe_diameter(point,personNum,kh,dql,t,pipeMaterialType)
        result = [] #结果
        pipeDiameter = 0 
        pipeDiameterRst = 0
        #计算该点的总当量
        allNg = 0
        equiInfo = 0
        @flowingEquipmentHash.each{|key,value|
            if (key.distance point) < 0.1
                equiInfo = value
                break
            end 
        }
        if equiInfo != 0
            equiInfo.each{|pItem|
                @pointEntHash.each{|key,value|
                    if (key.distance pItem) < 0.1
                        device = value
                        allNg += device["ql"].to_f*5
                        break
                    end 
                }
            }
            ng = allNg
            u0 = (100*dql*personNum*kh/(0.2*ng*t*3600)).to_f
            #若u0大于8则直接让u=1
            if u0.to_f <= 8
                #遍历key值取最近的两个，再根据线性规则得到ac的值
                u0ks = @u0acHash.keys
                tlist = [] 
                u0ks.each_cons(2){|items|
                    if u0.to_f <= items[1].to_f && u0.to_f >= items[0].to_f
                            tlist = items
                        break
                    end 
                }
                xielv = (@u0acHash[tlist[1]].to_f - @u0acHash[tlist[0]].to_f)/(tlist[1].to_f - tlist[0].to_f)
                ac = xielv*(u0-tlist[0].to_f) + @u0acHash[tlist[0]].to_f
                #计算U
                u = (1 + ac*(ng - 1)**0.49)/(ng**0.5)
            else
                u = 1
            end 
            qg = 0.2*u*ng
            #根据不同的水管材料及qg选出最符合条件的管径
            resultHash = {}
            if pipeMaterialType.include?("钢塑复合管")
                #遍历钢塑复合管的数据
                @dnPipeHash.each{|key,value|
                    v = (4*qg/(1000*Math::PI))/(value[0].to_f**2)
                    resultHash[key.to_i] = v
                }
                #分析计算结果(DN直径)
               pipeDiameterRst = parser_result(resultHash,@dnVHash)
               #实际内径
               pipeDiameter = @dnPipeHash[pipeDiameterRst][0]
            elsif pipeMaterialType.include?("PPR管")
                #遍历PPR管的数据
                @dnPipeHash.each{|key,value|
                    v = (4*qg/(1000*Math::PI))/(value[1].to_f**2)
                    resultHash[key.to_i] = v
                }
                #分析计算结果(DN直径)
                pipeDiameterRst = parser_result(resultHash,@dnVHash)
                #实际内径
                pipeDiameter = @dnPipeHash[pipeDiameterRst][1]
            elsif pipeMaterialType.include?("钢管")
                #遍历钢管的数据
                @dnPipeHash.each{|key,value|
                    v = (4*qg/(1000*Math::PI))/(value[2].to_f**2)
                    resultHash[key.to_i] = v
                }
                #分析计算结果(DN直径)
                pipeDiameterRst = parser_result(resultHash,@dnVHash)
                #实际内径
                pipeDiameter = @dnPipeHash[pipeDiameterRst][2]
            else
                p "无该种类型的水管"
            end 
        end
        result = [pipeDiameterRst, pipeDiameter]
        result
    end

    #分析计算结果
    def parser_result(resultHash,dnVHash)
        pipeDiameter = 0
        # p "resultHash : #{resultHash}"
        # p "dnVHash : #{dnVHash}"
        resultHash.each{|key,value|
            dnVHash.each{|dnKey,dnValue|
                #qg一定，管径越大，速度越小，故满足条件的第一项一定是误差最小的
                if key >= dnKey[0].to_f && key <= dnKey[1].to_f && value.to_f <= dnValue.to_f
                    pipeDiameter = key
                    break
                end 
            }
            break if pipeDiameter != 0
        }
        pipeDiameter
    end 

    #根据洁具额定流量得到该洁具的当量
    def get_device_by_ql(ql)
        ng = 0
        ng = ql*5
        ng
    end

    #根据住宅类别和最高用水定额dql来确定小时变化系数kh
    def get_kh_by_dql(houseType,dql)
        khRst = 0
        file = CSVData.find('住宅最高日生活用水定额及小时变化系数')
        dataList = file.all_row
        qlkhHash = {}
        dataList.each{|items|
            if items[0][/\d+/].to_f == houseType
                xs = items[1].split("~")
                ys = items[2].split("~")
                xielv = (ys[1][/\d+\.*\d*/].to_f - ys[0][/\d+\.*\d*/].to_f)/(xs[1][/\d+\.*\d*/].to_f - xs[0][/\d+\.*\d*/].to_f) 
                khRst = xielv*(dql - xs[0][/\d+\.*\d*/].to_f) + ys[0][/\d+\.*\d*/].to_f
                break
            end 
        }
        khRst
    end 

    # 卫生器具给水配件额定流量、当量、连接管公称管径和最低压力表
    def get_supply_and_fit_info
        file = TxtData.find('卫生器具给水配件额定流量、当量、连接管公称管径和最低压力表')
        contents = file.all_row
        contentHash = {}
        contents.each{|item|
            if contentHash[item[0].delete(" ")].nil?
                contentHash[item[0].delete(" ")] = []
                contentHash[item[0].delete(" ")] << [item[1].delete(" "),item[2].delete(" "),item[3].delete(" "),item[4].delete(" "),item[5].delete(" ")]
            else
                contentHash[item[0].delete(" ")] << [item[1].delete(" "),item[2].delete(" "),item[3].delete(" "),item[4].delete(" "),item[5].delete(" ")]
            end 

        }
        contentHash
    end 

    # u0与ac对应关系表
    def get_u0_to_ac_info
        u0acHash = {}
        file = CSVData.find('u0与ac对应关系表')
        dataList = file.all_row
        dataList.each{|items|
            u0acHash[items[0]] = items[1]
        }
        u0acHash
    end 

    # 公称直径与不同类型水管对应的内径表
    def get_dn_to_pipe_info 
        dnPipeHash = {}
        file2 = CSVData.find('公称直径与不同类型水管对应的内径表')
        dataList2 = file2.all_row
        dataList2.each{|items|
            dnPipeHash[items[0][/\d+/].to_i] = [items[1][/\d+\.*\d*/],items[2][/\d+\.*\d*/],items[3][/\d+\.*\d*/]]
        }
        dnPipeHash
    end 

    # 生活给水管道的水流速度
    def get_dn_to_v_info
        dnVHash = {}
        file3 = CSVData.find('生活给水管道的水流速度')
        dataList3 = file3.all_row
        dataList3.each{|items|
            lis = items[0].split("~")
            if lis.length == 2
                dnVHash[[lis[0][/\d+/], lis[1][/\d+/]]] = items[1][/\d+\.*\d*/]
            else
                dnVHash[[lis[0][/\d+/]]] = items[1][/\d+\.*\d*/]
            end 
        }
        dnVHash
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
	
	
	#在端点数组中找离目标端点最远距离的点
	def find_distance_max_point(oriPoint, points)
		#离oriPoint最远的点
		points.delete(oriPoint)
		dis_max = [points[0][0],points[0][1],oriPoint[2]].distance oriPoint
		points.each{|item|
			disFromS = [item[0],item[1],oriPoint[2]].distance oriPoint
			if disFromS > dis_max
				dis_max = disFromS
			end
		}
		distance_max_point = 0
		points.each{|item|
			if ([item[0],item[1],oriPoint[2]].distance oriPoint) == dis_max
				distance_max_point = item
				break
			end
		}
		distance_max_point
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
    def find_center_in_group(ent,normal,high,type, vecToWall = [-@vec_w[0],-@vec_w[1],-@vec_w[2]])
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
			downCenterPoints = []
			vecToWall_vi = Geom::Vector3d.new(vecToWall_vi)
			centerPoint = [centerPoint[0], centerPoint[1], highmin]
			if vecToWall_vi.samedirection?(@vec_l) 
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_w,75.mm)
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_w,-75.mm)
				# downCenterPoints = [[centerPoint[0],centerPoint[1]+75.mm,highmin], [centerPoint[0],centerPoint[1]-75.mm,highmin]]
				downCenterPoints = [transform_obj(downCenterPoints[0],group_max), transform_obj(downCenterPoints[1],group_max)]
			elsif vecToWall_vi.samedirection?(@vec_w)
				# downCenterPoints = [[centerPoint[0]-75.mm,centerPoint[1],highmin], [centerPoint[0]+75.mm,centerPoint[1],highmin]]
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_l,-75.mm)
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_l,75.mm)
				downCenterPoints = [transform_obj(downCenterPoints[0],group_max), transform_obj(downCenterPoints[1],group_max)]
			elsif vecToWall_vi.reverse.samedirection?(@vec_l)
				# downCenterPoints = [[centerPoint[0],centerPoint[1]-75.mm,highmin], [centerPoint[0],centerPoint[1]+75.mm,highmin]]
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_w,-75.mm)
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_w,75.mm)
				downCenterPoints = [transform_obj(downCenterPoints[0],group_max), transform_obj(downCenterPoints[1],group_max)]
			elsif vecToWall_vi.reverse.samedirection?(@vec_w)
				# downCenterPoints = [[centerPoint[0]+75.mm,centerPoint[1],highmin], [centerPoint[0]-75.mm,centerPoint[1],highmin]]
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_l,75.mm)
				downCenterPoints << get_point_move_by_vector(centerPoint,@vec_l,-75.mm)
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
    

    #画线
	def draw_line(pointList) 
		# @model.start_operation "Test", true
		pointList.each_cons(2){|item|
			@ents.add_line item[0], item[1]
		}
		# @model.commit_operation 
	end 


	#空间任意两点经过水平面连线的最近路线(含穿墙判断)
	def get_link_point_2(point1,point2,type,high)
		connectPointList = []
		point1_0 = [point1[0],point1[1],@zCoordinate+high] 
		point2_0 = [point2[0],point2[1],@zCoordinate+high] 
		connectPointList << point1 if point1_0 != point1
		
		line1 = [point1_0, Geom::Vector3d.new(@vec_l[0],@vec_l[1],@vec_l[2])]
		line2 = [point2_0, Geom::Vector3d.new(@vec_w[0],@vec_w[1],@vec_w[2])]
		point_vi = Geom.intersect_line_line(line1,line2)
		#判断是否穿墙
		result1 = judge_through_walls(point1_0,point_vi,type)
		flag1 = result1[0]
		result2 = judge_through_walls(point_vi,point2_0,type)
		flag2 = result2[0]
		#补充：如果有穿墙的话，先换个方向试试
        flag1_v, flag2_v, point_vi_v = 1, 1, 0    
		resFlag = false
		if flag1 == 1 || flag2 == 1
			line1_v = [point1_0, Geom::Vector3d.new(@vec_w[0],@vec_w[1],@vec_w[2])]
			line2_v = [point2_0, Geom::Vector3d.new(@vec_l[0],@vec_l[1],@vec_l[2])]
			point_vi_v = Geom.intersect_line_line(line1_v,line2_v)
			result1_v = judge_through_walls(point1_0,point_vi_v,type)
			flag1_v = result1[0]
			result2_v = judge_through_walls(point_vi_v,point2_0,type)
			flag2_v = result2[0]
			if flag1_v == 0 && flag2_v == 0
				resFlag = true
				connectPointList << point1 if !connectPointList.include?(point1)
				connectPointList << point1_0 if point1_0 != point1
				connectPointList << [point_vi_v[0],point_vi_v[1],point_vi_v[2]] if !connectPointList.include?([point_vi_v[0],point_vi_v[1],point_vi_v[2]])
				connectPointList << point2_0 if point2_0 != point2
				connectPointList << point2 if !connectPointList.include?(point2)
			end 
		end 
		if !resFlag 
            #优先穿墙少的路线
            if (flag1 + flag2) <= (flag1_v + flag2_v)
    			if flag2 == 1 #vec_w方向穿墙
    				polist = []
    				polist = move_line_with_vec(point1_0,point2_0,point_vi,@vec_w,type)
    				connectPointList.concat(polist)
    				connectPointList << point2 if point2_0 != point2
    				#再次判断是否穿墙
    				connectPointList_c = connectPointList.clone
    				connectPointList = [] #清空,重新加点
    				connectPointList_c.each_cons(2){|items|
    					points_s = []
    					points_s = get_link_point(items[0],items[1],type,high)
    					points_s = get_link_point_2(items[0],items[1],type,high) if points_s.size == 0
    					if points_s[0] != points_s[1]
    						points_s.pop if items[1] != connectPointList_c.last
    						connectPointList.concat(points_s) 
    					end
    				}
    				connectPointList = combinate_point_path(connectPointList)
    			elsif flag1 == 1 #vec_l方向穿墙
    				polist = []
    				polist = move_line_with_vec(point1_0,point2_0,point_vi,@vec_l,type)

    				connectPointList.concat(polist)
    				connectPointList << point2 if point2_0 != point2
    				#再次判断是否穿墙
    				connectPointList_c = connectPointList.clone
    				connectPointList = [] #清空,重新加点
    				connectPointList_c.each_cons(2){|items|
    					points_s = []
    					points_s = get_link_point(items[0],items[1],type,high)
    					points_s = get_link_point_2(items[0],items[1],type,high) if points_s.size == 0
    					if points_s[0] != points_s[1]
    						points_s.pop if items[1] != connectPointList_c.last
    						connectPointList.concat(points_s) 
    					end
    				}
    				connectPointList = combinate_point_path(connectPointList)
    			else
    				connectPointList << point1 if !connectPointList.include?(point1)
    				connectPointList << point1_0 if point1_0 != point1
    				connectPointList << [point_vi[0],point_vi[1],point_vi[2]] if !connectPointList.include?([point_vi[0],point_vi[1],point_vi[2]])
    				connectPointList << point2_0 if point2_0 != point2
    				connectPointList << point2 if !connectPointList.include?(point2)
    			end
            else
                if flag2_v == 1 #vec_l方向穿墙
                    polist = []
                    polist = move_line_with_vec(point1_0,point2_0,point_vi_v,@vec_l,type)
                    connectPointList.concat(polist)
                    connectPointList << point2 if point2_0 != point2
                    #再次判断是否穿墙
                    connectPointList_c = connectPointList.clone
                    connectPointList = [] #清空,重新加点
                    connectPointList_c.each_cons(2){|items|
                        points_s = []
                        points_s = get_link_point(items[0],items[1],type,high)
                        points_s = get_link_point_2(items[0],items[1],type,high) if points_s.size == 0
                        if points_s[0] != points_s[1]
                            points_s.pop if items[1] != connectPointList_c.last
                            connectPointList.concat(points_s) 
                        end
                    }
                    connectPointList = combinate_point_path(connectPointList)
                elsif flag1_v == 1 #vec_w方向穿墙
                    polist = []
                    polist = move_line_with_vec(point1_0,point2_0,point_vi_v,@vec_w,type)

                    connectPointList.concat(polist)
                    connectPointList << point2 if point2_0 != point2
                    #再次判断是否穿墙
                    connectPointList_c = connectPointList.clone
                    connectPointList = [] #清空,重新加点
                    connectPointList_c.each_cons(2){|items|
                        points_s = []
                        points_s = get_link_point(items[0],items[1],type,high)
                        points_s = get_link_point_2(items[0],items[1],type,high) if points_s.size == 0
                        if points_s[0] != points_s[1]
                            points_s.pop if items[1] != connectPointList_c.last
                            connectPointList.concat(points_s) 
                        end
                    }
                    connectPointList = combinate_point_path(connectPointList)
                else
                    connectPointList << point1 if !connectPointList.include?(point1)
                    connectPointList << point1_0 if point1_0 != point1
                    connectPointList << [point_vi_v[0],point_vi_v[1],point_vi_v[2]] if !connectPointList.include?([point_vi_v[0],point_vi_v[1],point_vi_v[2]])
                    connectPointList << point2_0 if point2_0 != point2
                    connectPointList << point2 if !connectPointList.include?(point2)
                end
            end # end if (flag1 + flag2) <= (flag1_v + flag2_v)
		end
		connectPointList = uniq_point_list(connectPointList)
		connectPointList
	end
	
	
	#空间任意两点经过水平面连线的最近路线(含约束条件，如穿墙判断)
	def get_link_point(point1,point2,type,high)
		connectPointList = []
		point1_0 = [point1[0],point1[1],@zCoordinate+high] 
		point2_0 = [point2[0],point2[1],@zCoordinate+high] 
		connectPointList << point1 if point1_0 != point1 
		connectPointList2 = []
		@disableVecList = []
		connectPointList2 = get_link_point_algorithm(point1_0, point2_0, @disableVecList, type) 
		if connectPointList2.length > 0
			connectPointList.concat(connectPointList2)
			connectPointList << point2 if point2_0 != point2 && !connectPointList.include?(point2)
			# connectPointList.uniq!
			connectPointList = uniq_point_list(connectPointList)
			connectPointList = combinate_point_path(connectPointList)
		else
			connectPointList = []
		end 
		connectPointList
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
	
	
	#连线迭代
	def get_link_point_algorithm(point1, point2, disableVecList, type)
		list = []
		rest = attachment_algorithm(point1,point2,disableVecList,type)
		if rest[1] != [] 
			wflag = false
			wflag2 = false
			rest[0].each_cons(2){|items|
				rest_1 = attachment_algorithm(items[0],items[1],disableVecList,type)
				if rest_1[1] != [] 
                    #补充，反方向时有可能出现（三点共线）
                    rest[1].each{|wItem|
                        rest_1[1].each{|wItem2|
                            if wItem == wItem2
                                wflag = true
                            end
                        }
                    }  
					rest_1[0].each_cons(2){|items_1|
						rest_2 = attachment_algorithm(items_1[0],items_1[1],disableVecList,type)
						if rest_2[1] != []
							#若rest[1] 与 rest_2[1]存在相同的墙，则该策略不可取(会循环穿墙)
							rest[1].each{|wItem|
								rest_2[1].each{|wItem2|
									if wItem == wItem2
										wflag = true
									end
								}
							}            
							if !wflag  #若墙不同,继续绕，直到无墙(可出)或墙相同（放弃该策略）
								rest_2[0].each_cons(2){|items_2|
									rest_3 = attachment_algorithm(items_2[0],items_2[1],disableVecList,type)
									if rest_3[1] != []
										rest_1[1].each{|wItem|
											rest_3[1].each{|wItem2|
												if wItem == wItem2
													wflag2 = true
												end
											}
										}
                                        if !wflag && !wflag2
                                            # 补充： 最后生成的线穿墙了，必不可行
                                            rest_3[0].each_cons(2){|items_3|
                                                rest_4 = attachment_algorithm(items_3[0],items_3[1],disableVecList,type)
                                                wflag2 = true if rest_4[1] != []
                                            }
                                        end 
									end
									list.concat(rest_3[0])
								}
							end 
						end
						list.concat(rest_2[0])
					}
                  
				else 
					list.concat(rest_1[0])
				end
			}
			if wflag == true || wflag2 == true 
				#放弃该策略
				vec = Geom::Vector3d.new(rest[0][1][0]-rest[0][0][0],rest[0][1][1]-rest[0][0][1],rest[0][1][2]-rest[0][0][2])
				if vec.samedirection?(@vec_l)
					disableVecList << @vec_l
				elsif vec.samedirection?(Geom::Vector3d.new(-@vec_l[0],-@vec_l[1],-@vec_l[2]))
					disableVecList << [-@vec_l[0],-@vec_l[1],-@vec_l[2]]
				elsif vec.samedirection?(@vec_w)
					disableVecList << @vec_w
				elsif vec.samedirection?(Geom::Vector3d.new(-@vec_w[0],-@vec_w[1],-@vec_w[2]))
					disableVecList << [-@vec_w[0],-@vec_w[1],-@vec_w[2]]
				end
				if disableVecList.length != 4
					list = get_link_point_algorithm(point1, point2, disableVecList,type)
				else
					# 所有方向都不行    
					list = []
				end
			end
		else
			list.concat(rest[0])
		end
		# list.uniq!
		list = uniq_point_list(list)
		list
	end 
	
	
	#算法  disableVecList禁止的方向
	def attachment_algorithm(point1,point2,disableVecList,type)
		pointList = []
		line1 = [point1, Geom::Vector3d.new(@vec_l)]
		line2 = [point2, Geom::Vector3d.new(@vec_w)]
		point12 = Geom.intersect_line_line line1, line2
		point12 = [point12[0],point12[1],point12[2]]
		
		result1 = judge_through_walls(point1,point12,type)
		result2 = judge_through_walls(point12,point2,type)

		#补充：如果有穿墙的话，先换个方向试试
        result1_v, result2_v = [], []
        result1_v[0], result2_v[0], point12_v = 1, 1, 0
		resFlag = false
		if result1[0] == 1 || result2[0] == 1
			line1_v = [point1, Geom::Vector3d.new(@vec_w)]
			line2_v = [point2, Geom::Vector3d.new(@vec_l)]
			point12_v = Geom.intersect_line_line line1_v, line2_v
			point12_v = [point12_v[0],point12_v[1],point12_v[2]]
			result1_v = judge_through_walls(point1,point12_v,type)
			result2_v = judge_through_walls(point12_v,point2,type)
			if result1_v[0] == 0 && result2_v[0] == 0
				resFlag = true
				pointList << point1
				pointList << point12_v if !pointList.include?(point12_v)
				pointList << point2 if !pointList.include?(point2)
			end 
		end 
		wallList = []
		if !resFlag
			stepLength=150.mm
            #优先穿墙少的路线
            if (result1[0] + result2[0]) <= (result1_v[0] + result2_v[0])
    			if result1[0] == 1 
    				wallList = result1[1]
    				#直接获取墙边端点
    				pointList = move_point_with_vec(point1,point2,point12,@vec_l,disableVecList,type,stepLength)
    			elsif result2[0] == 1
    				wallList = result2[1]
    				pointList = move_point_with_vec(point1,point2,point12,@vec_w,disableVecList,type,stepLength)
    			else
    				pointList << point1
    				pointList << point12 if !pointList.include?(point12)
    				pointList << point2 if !pointList.include?(point2)
    			end 
            else
                if result1_v[0] == 1 
                    wallList = result1_v[1]
                    #直接获取墙边端点
                    pointList = move_point_with_vec(point1,point2,point12_v,@vec_w,disableVecList,type,stepLength)
                elsif result2_v[0] == 1
                    wallList = result2_v[1]
                    pointList = move_point_with_vec(point1,point2,point12_v,@vec_l,disableVecList,type,stepLength)
                else
                    pointList << point1
                    pointList << point12_v if !pointList.include?(point12_v)
                    pointList << point2 if !pointList.include?(point2)
                end 
            end
		end 
		# pointList.uniq!
		pointList = uniq_point_list(pointList)
		[pointList,wallList]
	end 
	
	#线段穿墙时线段的移动方法
	#vec是穿墙方向,point1,point2连线两点 point12 两点往@vec_l,@vec_w连线的交点
	def move_point_with_vec(point1,point2,point12,vec,disableVecList,type, stepLength=150.mm)
		connectPointList = []
		stepLength = 150.mm #if stepLength.nil?
		if (disableVecList.include?(@vec_l) && disableVecList.include?([-@vec_l[0],-@vec_l[1],-@vec_l[2]])) || (vec == @vec_l && !(disableVecList.include?(@vec_w) && disableVecList.include?([-@vec_w[0],-@vec_w[1],-@vec_w[2]])))	
			#往@vec_w方向移动
			point1_vi = 0
			point12_vi = 0
			point2_vi = 0
			(1...100).each{|i|
				flag3 = 0
				flag4 = 0
				if !disableVecList.include?(@vec_w)
					point1_vi = [point1[0] + @vec_w_xleng*(stepLength*i), point1[1] + @vec_w_yleng*(stepLength*i), point1[2] + @vec_w_zleng*(stepLength*i)]
					point12_vi = [point12[0] + @vec_w_xleng*(stepLength*i), point12[1] + @vec_w_yleng*(stepLength*i), point12[2] + @vec_w_zleng*(stepLength*i)]
					result3 = judge_through_walls(point1,point1_vi,type)
					flag3 = result3[0]
					result4 = judge_through_walls(point1_vi,point12_vi,type)
					flag4 = result4[0]
				else
					flag4 = 1
				end
				if flag4 == 1 
					flag5 = 0
					flag6 = 0
					if  !disableVecList.include?([-@vec_w[0],-@vec_w[1],-@vec_w[2]])
						#反方向
						point1_vi = [point1[0] - @vec_w_xleng*(stepLength*i), point1[1] - @vec_w_yleng*(stepLength*i), point1[2] - @vec_w_zleng*(stepLength*i)]
						point12_vi = [point12[0] - @vec_w_xleng*(stepLength*i), point12[1] - @vec_w_yleng*(stepLength*i), point12[2] - @vec_w_zleng*(stepLength*i)]
						result5 = judge_through_walls(point1,point1_vi,type)
						result6 = judge_through_walls(point1_vi,point12_vi,type)
						flag5 = result5[0]
						flag6 = result6[0]
					else
						flag6 = 1  
					end
					if flag6 == 1  
						next
					else
						connectPointList << point1
						connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
						connectPointList << point12_vi
						connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
						connectPointList << point2	
						break
					end	
				else
					connectPointList << point1
					connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
					connectPointList << point12_vi
					connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
					connectPointList << point2	
					break
				end
			}
		elsif vec == @vec_w || (disableVecList.include?(@vec_w) && disableVecList.include?([-@vec_w[0],-@vec_w[1],-@vec_w[2]]))
			#往@vec_l方向移动
			point1_vi = 0
			point12_vi = 0
			point2_vi = 0
			(1...100).each{|i|
				flag3 = 0
				flag4 = 0
				if !disableVecList.include?(@vec_l)
					point12_vi = [point12[0] + @vec_l_xleng*(stepLength*i), point12[1] + @vec_l_yleng*(stepLength*i), point12[2] + @vec_l_zleng*(stepLength*i)]
					point2_vi = [point2[0] + @vec_l_xleng*(stepLength*i), point2[1] + @vec_l_yleng*(stepLength*i), point2[2] + @vec_l_zleng*(stepLength*i)]
					result3 = judge_through_walls(point12_vi,point2_vi,type)
					result4 = judge_through_walls(point2_vi,point2,type)
					flag3 = result3[0]
					flag4 = result4[0]
				else
 					flag3 = 1 
				end
				if flag3 == 1 
					flag5 = 0
					flag6 = 0
					if !disableVecList.include?([-@vec_l[0],-@vec_l[1],-@vec_l[2]])
						#反方向
						point12_vi = [point12[0] - @vec_l_xleng*(stepLength*i), point12[1] - @vec_l_yleng*(stepLength*i), point12[2] - @vec_l_zleng*(stepLength*i)]
						point2_vi = [point2[0] - @vec_l_xleng*(stepLength*i), point2[1] - @vec_l_yleng*(stepLength*i), point2[2] - @vec_l_zleng*(stepLength*i)]
						result5 = judge_through_walls(point12_vi,point2_vi,type)
						result6 = judge_through_walls(point2_vi,point2,type)
						flag5 = result5[0]
						flag6 = result6[0]
					else
						flag5 = 1
					end
					if flag5 == 1  
						next					
					elsif flag5 != 1 && flag6 != 1
						connectPointList << point1
						connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
						connectPointList << point12_vi
						connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
						connectPointList << point2	
						break
					end	
				elsif  
					connectPointList << point1
					connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
					connectPointList << point12_vi
					connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
					connectPointList << point2	
					break
				end
			}
		end 
		connectPointList
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
				if !vec1.nil? && !vec2.nil? && vec1.length > 0.1.mm && vec2.length > 0.1.mm
					if judge_two_vectors_parallel(vec1, vec2) 
						#删除中间点
						points_c.delete(items[1])
					end 
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
	
	#线段穿墙时线段的移动方法
	#vec是穿墙方向,point1,point2连线两点 point12 两点往@vec_l,@vec_w连线的交点
	def move_line_with_vec(point1,point2,point12,vec,type)
		connectPointList = []
		stepLength = 150.mm
		if vec == @vec_l
			#往@vec_w方向移动
			point1_vi = 0
			point12_vi = 0
			point2_vi = 0
			(1...100).each{|i|
				point1_vi = [point1[0] + @vec_w_xleng*(stepLength*i), point1[1] + @vec_w_yleng*(stepLength*i), point1[2] + @vec_w_zleng*(stepLength*i)]
				point12_vi = [point12[0] + @vec_w_xleng*(stepLength*i), point12[1] + @vec_w_yleng*(stepLength*i), point12[2] + @vec_w_zleng*(stepLength*i)]
				result3 = judge_through_walls(point1,point1_vi,type)
				flag3 = result3[0]
				result4 = judge_through_walls(point1_vi,point12_vi,type)
				flag4 = result4[0]
				if flag4 == 1 
					#反方向
					point1_vi = [point1[0] - @vec_w_xleng*(stepLength*i), point1[1] - @vec_w_yleng*(stepLength*i), point1[2] - @vec_w_zleng*(stepLength*i)]
					point12_vi = [point12[0] - @vec_w_xleng*(stepLength*i), point12[1] - @vec_w_yleng*(stepLength*i), point12[2] - @vec_w_zleng*(stepLength*i)]
					result5 = judge_through_walls(point1,point1_vi,type)
					result6 = judge_through_walls(point1_vi,point12_vi,type)
					flag5 = result5[0]
					flag6 = result6[0]
					if flag6 == 1  
						next
					else
						connectPointList << point1
						connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
						connectPointList << point12_vi
						connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
						connectPointList << point2	
						break
					end	
				else
					connectPointList << point1
					connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
					connectPointList << point12_vi
					connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
					connectPointList << point2	
					break
				end
			}
		elsif vec == @vec_w
			#往@vec_l方向移动
			point1_vi = 0
			point12_vi = 0
			point2_vi = 0
			(1...100).each{|i|
				point12_vi = [point12[0] + @vec_l_xleng*(stepLength*i), point12[1] + @vec_l_yleng*(stepLength*i), point12[2] + @vec_l_zleng*(stepLength*i)]
				point2_vi = [point2[0] + @vec_l_xleng*(stepLength*i), point2[1] + @vec_l_yleng*(stepLength*i), point2[2] + @vec_l_zleng*(stepLength*i)]
				result3 = judge_through_walls(point12_vi,point2_vi,type)
				result4 = judge_through_walls(point2_vi,point2,type)
				flag3 = result3[0]
				flag4 = result4[0]
				if flag3 == 1 
					#反方向
					point12_vi = [point12[0] - @vec_l_xleng*(stepLength*i), point12[1] - @vec_l_yleng*(stepLength*i), point12[2] - @vec_l_zleng*(stepLength*i)]
					point2_vi = [point2[0] - @vec_l_xleng*(stepLength*i), point2[1] - @vec_l_yleng*(stepLength*i), point2[2] - @vec_l_zleng*(stepLength*i)]
					result5 = judge_through_walls(point12_vi,point2_vi,type)
					result6 = judge_through_walls(point2_vi,point2,type)
					flag5 = result5[0]
					flag6 = result6[0]
					if flag5 == 1  
						next					
					else
						connectPointList << point1
						connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
						connectPointList << point12_vi
						connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
						connectPointList << point2	
						break
					end	
				elsif  
					connectPointList << point1
					connectPointList << point1_vi if (point1_vi != point1 && point1_vi != 0)
					connectPointList << point12_vi
					connectPointList << point2_vi if (point2_vi != point2 && point2_vi != 0)
					connectPointList << point2	
					break
				end
			}
		end 
		connectPointList
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
	
    def judge_through_walls(point1,point2,type)
        vec12 = [point2[0]-point1[0], point2[1]-point1[1], point2[2]-point1[2]]
        line1 = [point1, Geom::Point3d.new(point2)]
        distance12 = point1.distance point2
        result = []
        result[0] = 0
        result[1] = []
        flag = 0 #穿墙标志
        @wallFaceListRel.each{|item|
            item2point0 = item.vertices[0].position
            item2point0 = [item2point0[0],item2point0[1],point1[2]]
            plane = [item2point0, Geom::Vector3d.new(item.normal)]
            point_vi = Geom.intersect_line_plane(line1,plane)

            if !point_vi.nil?
                #交点在线段上并且在墙上
                distance1_vi = point1.distance point_vi
                distance2_vi = point2.distance point_vi
                if (distance1_vi <= distance12) && (distance2_vi <= distance12) && (item.classify_point(point_vi) == 1 || item.classify_point(point_vi) == 2 || item.classify_point(point_vi) == 4)
                    flag = 1 
                    result[1] << item
                end
            end
        }
        if type == "hot"
            #增加对是否穿线穿点的判断（是否穿过冷水管）
            flag_2 = false
            @coldLinesPoint.each{|item2|
                flag_2 = judge_point_in_segment(item2,point1,point2)
                 if flag_2
                    flag = 1
                    result[1] << item2 
                    break
                 end 
            }
        elsif type == "cold"
            plist = []
            @hotDevicePointList.each{|items|
                plist << [items[0],items[1],0.mm]
            }
            flag_2 = false
            if plist.size > 0
                plist.each{|item2|
                    flag_2 = judge_point_in_segment(item2,point1,point2)
                     if flag_2
                        flag = 1
                        result[1] << item2
                        break
                     end 
                }
            end
        end         
        result[0] = flag
        result
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
		segemnts.each{|items|
			# line = @ents.add_line items[0], items[1]
            line = @lineGroupEnt.add_line items[0], items[1]       
			if type == "hot"
				line.material = "red" if !line.nil?
			end 
		}
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

	#冒泡排序
	def bubbleSort(array)
		return array if array.size < 2
		(array.size - 2).downto(0) do |i|
			(0 .. i).each do |j|
				array[j], array[j + 1] = array[j + 1], array[j] if array[j] >= array[j + 1]
			end
		end
		return array
	end

	#找出指定群组或组件中的箭头端点, 两进一出(一热一冷,一排)
	def get_arrowPoints_in_group(gEnt)
		arrowPoints = []
		supplyPoints = [] #给水点
		drainagePoints = [] #排水点

		if gEnt.typename == "Group"
			gEnt.entities.each{|item|
				if item.typename == "Edge"
					if item.start.edges.size == 3 && item.end.edges.size == 1
						if item.start.position[2] > item.end.position[2]
							edge1 = item.start.edges[0]
							edge2 = item.start.edges[1]
							edge3 = item.start.edges[2]
							flag1 = judge_two_edge_is_rightAngle(edge1,edge2)
							flag2 = judge_two_edge_is_rightAngle(edge1,edge3)
							flag3 = judge_two_edge_is_rightAngle(edge2,edge3)
							supplyPoints << item.start.position if !flag1 && !flag2 && !flag3
						elsif item.start.position[2] < item.end.position[2]
							edge1 = item.start.edges[0]
							edge2 = item.start.edges[1]
							edge3 = item.start.edges[2]
							flag1 = judge_two_edge_is_rightAngle(edge1,edge2)
							flag2 = judge_two_edge_is_rightAngle(edge1,edge3)
							flag3 = judge_two_edge_is_rightAngle(edge2,edge3)
							drainagePoints << item.start.position if !flag1 && !flag2 && !flag3
						end
					elsif item.end.edges.size == 3 && item.start.edges.size == 1
						if item.end.position[2] > item.start.position[2]
							edge1 = item.end.edges[0]
							edge2 = item.end.edges[1]
							edge3 = item.end.edges[2]
							flag1 = judge_two_edge_is_rightAngle(edge1,edge2)
							flag2 = judge_two_edge_is_rightAngle(edge1,edge3)
							flag3 = judge_two_edge_is_rightAngle(edge2,edge3)
							supplyPoints << item.end.position if !flag1 && !flag2 && !flag3
						elsif item.end.position[2] < item.start.position[2]
							edge1 = item.end.edges[0]
							edge2 = item.end.edges[1]
							edge3 = item.end.edges[2]
							flag1 = judge_two_edge_is_rightAngle(edge1,edge2)
							flag2 = judge_two_edge_is_rightAngle(edge1,edge3)
							flag3 = judge_two_edge_is_rightAngle(edge2,edge3)
							drainagePoints << item.end.position if !flag1 && !flag2 && !flag3
						end
					end 
				end
			}
		end
		arrowPoints = [supplyPoints, drainagePoints]
		arrowPoints
	end

	#判断两边夹角是否为90度
	def judge_two_edge_is_rightAngle(edge1,edge2)
		flag = false
		e1sPosition = edge1.start.position
		e1ePosition = edge1.end.position
		e2sPosition = edge2.start.position
		e2ePosition = edge2.end.position
		vec1 = Geom::Vector3d.new(e1ePosition[0] - e1sPosition[0], e1ePosition[1] - e1sPosition[1], e1ePosition[2] - e1sPosition[2])
		vec2 = Geom::Vector3d.new(e2ePosition[0] - e2sPosition[0], e2ePosition[1] - e2sPosition[1], e2ePosition[2] - e2sPosition[2])
		if !vec1.nil? && !vec2.nil? && vec1.dot(vec2).abs < 0.1 
			flag = true
		end
		flag
	end


end 

t1 = Time.now
begin
    timeout(60) do 
        WaterSupplyPipeline.new.run([0,0,1], 0.mm, 0.mm,[3020.mm, 5010.mm,0],"钢管","2","250","3.5","24")
    end 
rescue Exception => e
    p e.message
    p "程序执行时间已过60s，超时!"
end 
t2 = Time.now
p "耗时：#{t2.to_i - t1.to_i}s"