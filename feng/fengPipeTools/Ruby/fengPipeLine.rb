
class FengPipeLine
    def run(pointList, normal, high, distanceFromWall = 0,attachment_direction)
        @distance = distanceFromWall
        @model = Sketchup.active_model
        @ents = @model.active_entities
        @model.start_operation "Link Feng Line Test", true
        @allLines = []
        @allPoints = []
        @normal = normal
        zCoordinate = 0
        @zCoordinate = zCoordinate
        @high = high
        @distanceFromWall = distanceFromWall
        if attachment_direction.include?("x轴")
            @attachment_direction = [1,0,0]
        else
            @attachment_direction = [0,1,0]
        end 
        if pointList.length >= 2
            pointList.each_cons(2){|item|
                run2(item[0],item[1]) if item[0] != item[1]
            }
        else
            p "至少需要两个待连接点"
        end

        @model.commit_operation 
    end 


    def  run2(point1,point2)    
        @vec_l = [1,0,0]
        @vec_w = [0,1,0]
        vec_l_leng = [0,0,0].distance @vec_l
        vec_w_leng = [0,0,0].distance @vec_w
        @vec_l_xleng = @vec_l[0]/vec_l_leng
        @vec_l_yleng = @vec_l[1]/vec_l_leng
        @vec_l_zleng = @vec_l[2]/vec_l_leng
        @vec_w_xleng = @vec_w[0]/vec_w_leng
        @vec_w_yleng = @vec_w[1]/vec_w_leng
        @vec_w_zleng = @vec_w[2]/vec_w_leng

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
                value = item.get_attribute('DFC_结构', '类别', 0)
                value2 = item.get_attribute('Wall', '墙高', 0)
                if value != 0
                    attributeHash = {}
                    attributeHash["ent"] = item
                    attributeHash["name"] = value.to_s
                    attributeHash["high"] = value2.to_s
                    @attributeHashList << attributeHash
                else
                    attributeHash = {}
                    attributeHash["ent"] = item
                    @attributeHashList << attributeHash
                end
            }
        end 
        if @instanceList.size > 0
            @instanceList.each{|item|
                value = item.get_attribute('DFC_结构', '类别', 0)
                value2 = item.get_attribute('Wall', '墙高', 0)
                if value != 0
                    attributeHash = {}
                    attributeHash["ent"] = item
                    attributeHash["name"] = value.to_s
                    attributeHash["high"] = value2.to_s
                    @attributeHashList << attributeHash
                else
                    attributeHash = {}
                    attributeHash["ent"] = item
                    @attributeHashList << attributeHash
               end
            }
        end
        # p "@attributeHashList : #{@attributeHashList}"

        @wallFaceList = []
        find_wall_faces()

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
        begin
            #修正端点，定位到指定位置
             point1 = [point1[0],point1[1],@zCoordinate+@high]
             point2 = [point2[0],point2[1],@zCoordinate+@high]
            # p "point1,point2 : "
            # show_mm_points([point1,point2])
            #判断端点是否在墙上，若是，则直接退出(或偏移)，否则开始连接
            rest1 = judge_point_is_on_wall(point1)
            rest2 = judge_point_is_on_wall(point2)
            point1 = get_point_move_by_vector(point1,rest1[1].normal,@distanceFromWall) if rest1[0]
            point2 = get_point_move_by_vector(point2,rest2[1].normal,@distanceFromWall) if rest2[0]

            pointList = []
            begin
                timeout(3) do 
                    pointList = get_link_point(point1,point2,"0",@high)
                end
            rescue Exception => e 
            end
            pointList = get_link_point_2(point1,point2,"0",@high) if pointList.size == 0

            pointList = pipeline_migrate_distance_from_wall(pointList, @distanceFromWall, "0")
            group1 = draw_line_by_points(pointList)
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

        group1
    end 

    #判断端点是否在墙面上
    def judge_point_is_on_wall(point)
        point = Geom::Point3d.new(point)
        result = []
        flag = false
        onFace = 0
        @wallFaceListRel.each{|fItem|
            if fItem.classify_point(point) == 1 || fItem.classify_point(point) == 2 || fItem.classify_point(point) == 4
                flag = true
                onFace = fItem
                break
            end
        }
        result = [flag, onFace]
        result
    end
  

    #空间任意两点经过水平面连线的最近路线(含穿墙判断)
    def get_link_point_2(point1,point2,type,high)
        connectPointList = []
        point1_0 = [point1[0],point1[1],@zCoordinate+high] 
        point2_0 = [point2[0],point2[1],@zCoordinate+high] 
        connectPointList << point1 if point1_0 != point1
        if @attachment_direction == [1,0,0]
            line1 = [point1_0, Geom::Vector3d.new(@vec_l[0],@vec_l[1],@vec_l[2])]
            line2 = [point2_0, Geom::Vector3d.new(@vec_w[0],@vec_w[1],@vec_w[2])]
        else
            line1 = [point1_0, Geom::Vector3d.new(@vec_w[0],@vec_w[1],@vec_w[2])]
            line2 = [point2_0, Geom::Vector3d.new(@vec_l[0],@vec_l[1],@vec_l[2])]
        end 
        point_vi = Geom.intersect_line_line(line1,line2)
        #判断是否穿墙
        result1 = judge_through_walls(point1_0,point_vi,type)
        flag1 = result1[0]
        result2 = judge_through_walls(point_vi,point2_0,type)
        flag2 = result2[0]
        #补充：如果有穿墙的话，先换个方向试试
        resFlag = false
        if flag1 == 1 || flag2 == 1
            if @attachment_direction == [1,0,0]
                line1_v = [point1_0, Geom::Vector3d.new(@vec_w[0],@vec_w[1],@vec_w[2])]
                line2_v = [point2_0, Geom::Vector3d.new(@vec_l[0],@vec_l[1],@vec_l[2])]
            else
                line1_v = [point1_0, Geom::Vector3d.new(@vec_l[0],@vec_l[1],@vec_l[2])]
                line2_v = [point2_0, Geom::Vector3d.new(@vec_w[0],@vec_w[1],@vec_w[2])]
            end 
            point_vi_v = Geom.intersect_line_line(line1_v,line2_v)
            result1_v = judge_through_walls(point1_0,point_vi_v,type)
            flag1_v = result1_v[0]
            result2_v = judge_through_walls(point_vi_v,point2_0,type)
            flag2_v = result2_v[0]
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
            if flag2 == 1 #vec_w方向穿墙
                polist = []
                if @attachment_direction == [1,0,0]
                    polist = move_line_with_vec(point1_0,point2_0,point_vi,@vec_w,type)
                else
                    polist = move_line_with_vec(point1_0,point2_0,point_vi,@vec_l,type)
                end 
                connectPointList.concat(polist)
                connectPointList << point2 if point2_0 != point2
                #再次判断是否穿墙
                connectPointList_c = connectPointList.clone
                connectPointList = [] #清空,重新加点
                # p "connectPointList_c   11111111: "
                # show_mm_points(connectPointList_c)
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
                if @attachment_direction == [1,0,0]
                    polist = move_line_with_vec(point1_0,point2_0,point_vi,@vec_l,type)
                else
                    polist = move_line_with_vec(point1_0,point2_0,point_vi,@vec_w,type)
                end 
                connectPointList.concat(polist)
                connectPointList << point2 if point2_0 != point2
                #再次判断是否穿墙
                connectPointList_c = connectPointList.clone
                connectPointList = [] #清空,重新加点
                #  p "connectPointList_c  2222222222: "
                # show_mm_points(connectPointList_c)
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
        # connectPointList2 = get_link_point_algorithm_2(point1_0, point2_0, @disableVecList, type) 
        # p "connectPointList2 : "
        # show_mm_points(connectPointList2)
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
    

    #连线迭代
    def get_link_point_algorithm(point1, point2, disableVecList, type)
        list = []
        rest = attachment_algorithm(point1,point2,disableVecList,type)
        # p "rest : #{rest}"
        if rest[1] != [] 
            wflag = false
            wflag2 = false
            rest[0].each_cons(2){|items|
                rest_1 = attachment_algorithm(items[0],items[1],disableVecList,type)
                 # p "rest_1 : #{rest_1}"
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
                        # p "rest_2 : #{rest_2}"
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
                                    # p "rest_3 : #{rest_3}"
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
                                                # p "rest_4 : #{rest_4}"
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
                # p "放弃该策略 : #{disableVecList}"
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
    

    #连线迭代2 测试
    def get_link_point_algorithm_2(point1, point2, disableVecList, type)
        # p "get_link_point_algorithm_2 "
        list = []
        rest = attachment_algorithm(point1,point2,disableVecList,type)
        rest0sList = []
        rest1sList = []
        if rest[1] != [] 
            rest0sList << [rest[0]]
            rest1sList << [rest[1]]
            wflag = false
            wflag2 = false
 
            (1..10).each{|i|
                rest0s = []
                rest1s = []
                rest0sList.last.each{|last0Item|
                    last0Item.each_cons(2){|items_1|
                        lastResults = attachment_algorithm(items_1[0],items_1[1],disableVecList,type)
                        rest0s << lastResults[0]
                        if lastResults[1] != [] 
                            lastResults[1].each{|litem|
                                rest1s << litem
                            }
                            #补充，反方向时有可能出现（三点共线）
                            rest[1].each{|wItem|
                                lastResults[1].each{|wItem2|
                                    if wItem == wItem2
                                        wflag = true
                                    end
                                }
                            }  
                        else
                            list.concat(lastResults[0])
                        end 
                    }
                }
                rest0sList << rest0s
                #若穿的墙已存在则放弃
                if rest1s != []
                    rest1s.each{|witem|
                        rest1sList.each{|wlitem|
                            if wlitem.include?(witem)
                                wflag2 = true #不可行
                            end 
                        }
                    }
                    rest1sList << rest1s
                end
                break if rest1s == []  #最后所有线段不穿墙时结束
           
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
                    list = get_link_point_algorithm_2(point1, point2, disableVecList,type)
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
        if @attachment_direction == [1,0,0]
            line1 = [point1, Geom::Vector3d.new(@vec_l)]
            line2 = [point2, Geom::Vector3d.new(@vec_w)]
        else
            line1 = [point1, Geom::Vector3d.new(@vec_w)]
            line2 = [point2, Geom::Vector3d.new(@vec_l)]
        end
        point12 = Geom.intersect_line_line line1, line2
        point12 = [point12[0],point12[1],point12[2]]
        
        result1 = judge_through_walls(point1,point12,type)
        result2 = judge_through_walls(point12,point2,type)

        #补充：如果有穿墙的话，先换个方向试试
        result1_v, result2_v = [], []
        result1_v[0], result2_v[0] = 1, 1
        point12_v = 0
        resFlag = false
        if result1[0] == 1 || result2[0] == 1
            if @attachment_direction == [1,0,0]
                line1_v = [point1, Geom::Vector3d.new(@vec_w)]
                line2_v = [point2, Geom::Vector3d.new(@vec_l)]
            else
                line1_v = [point1, Geom::Vector3d.new(@vec_l)]
                line2_v = [point2, Geom::Vector3d.new(@vec_w)]
            end
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
            stepLength = @distanceFromWall
            #优先穿墙少的
            if (result1[0] + result2[0]) <= (result1_v[0] + result2_v[0])
                if result1[0] == 1 
                    wallList = result1[1]
                    if @attachment_direction == [1,0,0]
                        pointList = move_point_with_vec(point1,point2,point12,@vec_l,disableVecList,type,stepLength)
                    else
                        pointList = move_point_with_vec(point1,point2,point12,@vec_w,disableVecList,type,stepLength)
                    end
                elsif result2[0] == 1
                    wallList = result2[1]
                    if @attachment_direction == [1,0,0]
                        pointList = move_point_with_vec(point1,point2,point12,@vec_w,disableVecList,type,stepLength)
                    else
                        pointList = move_point_with_vec(point1,point2,point12,@vec_l,disableVecList,type,stepLength)
                    end
                else
                    pointList << point1
                    pointList << point12 if !pointList.include?(point12)
                    pointList << point2 if !pointList.include?(point2)
                end 
            else
                if result1_v[0] == 1 
                    wallList = result1[1]
                    if @attachment_direction == [1,0,0]
                        pointList = move_point_with_vec(point1,point2,point12_v,@vec_w,disableVecList,type,stepLength)
                    else
                        pointList = move_point_with_vec(point1,point2,point12_v,@vec_l,disableVecList,type,stepLength)
                    end
                elsif result2_v[0] == 1
                    wallList = result2[1]
                    if @attachment_direction == [1,0,0]
                        pointList = move_point_with_vec(point1,point2,point12_v,@vec_l,disableVecList,type,stepLength)
                    else
                        pointList = move_point_with_vec(point1,point2,point12_v,@vec_w,disableVecList,type,stepLength)
                    end
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
        stepLength = @distanceFromWall #if stepLength.nil?
        if @attachment_direction == [1,0,0]
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
        else
            if (disableVecList.include?(@vec_l) && disableVecList.include?([-@vec_l[0],-@vec_l[1],-@vec_l[2]])) || (vec == @vec_l && !(disableVecList.include?(@vec_w) && disableVecList.include?([-@vec_w[0],-@vec_w[1],-@vec_w[2]]))) 
                #往@vec_w方向移动
                point1_vi = 0
                point12_vi = 0
                point2_vi = 0
                (1...100).each{|i|
                    flag3 = 0
                    flag4 = 0
                    if !disableVecList.include?(@vec_w)
                        point12_vi = [point12[0] + @vec_w_xleng*(stepLength*i), point12[1] + @vec_w_yleng*(stepLength*i), point12[2] + @vec_w_zleng*(stepLength*i)]
                        point2_vi = [point2[0] + @vec_w_xleng*(stepLength*i), point2[1] + @vec_w_yleng*(stepLength*i), point2[2] + @vec_w_zleng*(stepLength*i)]
                        result3 = judge_through_walls(point12,point12_vi,type)
                        flag3 = result3[0]
                        result4 = judge_through_walls(point12_vi,point2_vi,type)
                        flag4 = result4[0]
                    else
                        flag4 = 1
                    end
                    if flag4 == 1 
                        flag5 = 0
                        flag6 = 0
                        if  !disableVecList.include?([-@vec_w[0],-@vec_w[1],-@vec_w[2]])
                            #反方向
                            point12_vi = [point12[0] - @vec_w_xleng*(stepLength*i), point12[1] - @vec_w_yleng*(stepLength*i), point12[2] - @vec_w_zleng*(stepLength*i)]
                            point2_vi = [point2[0] - @vec_w_xleng*(stepLength*i), point2[1] - @vec_w_yleng*(stepLength*i), point2[2] - @vec_w_zleng*(stepLength*i)]
                            result5 = judge_through_walls(point12,point12_vi,type)
                            result6 = judge_through_walls(point12_vi,point2_vi,type)
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
                        point1_vi = [point1[0] + @vec_l_xleng*(stepLength*i), point1[1] + @vec_l_yleng*(stepLength*i), point1[2] + @vec_l_zleng*(stepLength*i)]
                        point12_vi = [point12[0] + @vec_l_xleng*(stepLength*i), point12[1] + @vec_l_yleng*(stepLength*i), point12[2] + @vec_l_zleng*(stepLength*i)]
                        result3 = judge_through_walls(point1_vi,point12_vi,type)
                        result4 = judge_through_walls(point12_vi,point12,type)
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
                            point1_vi = [point1[0] - @vec_l_xleng*(stepLength*i), point1[1] - @vec_l_yleng*(stepLength*i), point1[2] - @vec_l_zleng*(stepLength*i)]
                            point12_vi = [point12[0] - @vec_l_xleng*(stepLength*i), point12[1] - @vec_l_yleng*(stepLength*i), point12[2] - @vec_l_zleng*(stepLength*i)]
                            result5 = judge_through_walls(point1_vi,point12_vi,type)
                            result6 = judge_through_walls(point12_vi,point12,type)
                            flag5 = result5[0]
                            flag6 = result6[0]
                        else
                            flag5 = 1
                        end
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
        end
        connectPointList
    end 

    #vec是穿墙方向,point1,point2连线两点 point12 两点往@vec_l,@vec_w连线的交点
    def move_line_with_vec(point1,point2,point12,vec,type)
        connectPointList = []
        stepLength = @distanceFromWall
        if @attachment_direction == [1,0,0]
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
        else
            if vec == @vec_l
                #往@vec_w方向移动
                point1_vi = 0
                point12_vi = 0
                point2_vi = 0
                (1...100).each{|i|
                    point12_vi = [point12[0] + @vec_w_xleng*(stepLength*i), point12[1] + @vec_w_yleng*(stepLength*i), point12[2] + @vec_w_zleng*(stepLength*i)]
                    point2_vi = [point2[0] + @vec_w_xleng*(stepLength*i), point2[1] + @vec_w_yleng*(stepLength*i), point2[2] + @vec_w_zleng*(stepLength*i)]
                    result3 = judge_through_walls(point12,point12_vi,type)
                    flag3 = result3[0]
                    result4 = judge_through_walls(point12_vi,point2_vi,type)
                    flag4 = result4[0]
                    if flag4 == 1 
                        #反方向
                        point12_vi = [point12[0] - @vec_w_xleng*(stepLength*i), point12[1] - @vec_w_yleng*(stepLength*i), point12[2] - @vec_w_zleng*(stepLength*i)]
                        point2_vi = [point2[0] - @vec_w_xleng*(stepLength*i), point2[1] - @vec_w_yleng*(stepLength*i), point2[2] - @vec_w_zleng*(stepLength*i)]
                        result5 = judge_through_walls(point12,point12_vi,type)
                        result6 = judge_through_walls(point12_vi,point2_vi,type)
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
                    point1_vi = [point1[0] + @vec_l_xleng*(stepLength*i), point1[1] + @vec_l_yleng*(stepLength*i), point1[2] + @vec_l_zleng*(stepLength*i)]
                    point12_vi = [point12[0] + @vec_l_xleng*(stepLength*i), point12[1] + @vec_l_yleng*(stepLength*i), point12[2] + @vec_l_zleng*(stepLength*i)]
                    result3 = judge_through_walls(point1_vi,point12_vi,type)
                    result4 = judge_through_walls(point12_vi,point12,type)
                    flag3 = result3[0]
                    flag4 = result4[0]
                    if flag3 == 1 
                        #反方向
                        point1_vi = [point1[0] - @vec_l_xleng*(stepLength*i), point1[1] - @vec_l_yleng*(stepLength*i), point2[2] - @vec_l_zleng*(stepLength*i)]
                        point12_vi = [point12[0] - @vec_l_xleng*(stepLength*i), point12[1] - @vec_l_yleng*(stepLength*i), point12[2] - @vec_l_zleng*(stepLength*i)]
                        result5 = judge_through_walls(point1_vi,point12_vi,type)
                        result6 = judge_through_walls(point12_vi,point12,type)
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

        end 
        connectPointList
    end 


    #穿墙判断
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
                            # face1 = item2
                            # fgroup = find_max_group_by_ent(item2)
                            # if fgroup != 0
                            #     face1 = transform_face(item2, fgroup)
                            # end 
                            distance = distance_from_segement_to_face([pitems[0],pitems[1]], item)
                            if distance > 0.1.mm && distance < distanceFromWall
                                distoff = distanceFromWall - distance
                                if  judge_two_vectors_parallel(vec, @vec_l)         
                                    pitems0_vi = [pitems[0][0] + @vec_w_xleng*distoff, pitems[0][1] + @vec_w_yleng*distoff, pitems[0][2] + @vec_w_zleng*distoff]
                                    pitems1_vi = [pitems[1][0] + @vec_w_xleng*distoff, pitems[1][1] + @vec_w_yleng*distoff, pitems[1][2] + @vec_w_zleng*distoff]
                                    distance_vi = distance_from_segement_to_face([pitems0_vi,pitems1_vi], item)
                                    
                                    #移动后点和原来端点在墙的同一边
                                    line2 = [pitems[0],item.normal]
                                    # plane = [transform_obj(item.vertices[0].position,fgroup),item.normal]
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
                                    # plane = [transform_obj(item2.vertices[0].position, fgroup),item.normal]
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
                        
                            #删除面
                            # if face1 != item2   
                            #     begin
                            #         face1.edges.each{|eItem|
                            #             eItem.erase!
                            #         }
                            #     rescue Exception => e 
                            #     end 
                            # end 
                        end
                    end
                }
             
            end # 只考虑同一水平面的 end 
        }
        points
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
                distance = segment[1].distance point_ins_2
            elsif !point_ins_wall.nil? 
                flag = judge_point_in_segment(point_ins_wall,segment[0],segment[1])
                distance = point_ins_wall.distance(wallpoint) if flag
            end
        end
        distance
    end 

    
    #判断两向量是否平行,因为可能有误差，导致不一定是0度或180
    def judge_two_vectors_parallel(vec1,vec2)
        flag = false
        if vec1.angle_between(vec2).abs < 0.1 || (vec1.angle_between(vec2) - 3.14).abs < 0.1
            flag = true
        end 
        flag
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

 
    #三点路径结合（删除重复线段）
    def combinate_point_path(points)
        points_c = points.clone
        if points.size > 2
            points.each_cons(3){|items|
                vec1 = Geom::Vector3d.new(items[1][0]-items[0][0],items[1][1]-items[0][1],items[1][2]-items[0][2]) 
                vec2 = Geom::Vector3d.new(items[2][0]-items[1][0],items[2][1]-items[1][1],items[2][2]-items[1][2]) 
                if !vec1.nil? && !vec2.nil? && vec1.length > 0.1.mm && vec2.length > 0.1.mm
                    if vec1.reverse.samedirection?(vec2) || vec1.samedirection?(vec2)
                        #删除中间点
                        points_c.delete(items[1])
                    end 
                end
            }
        end
        points_c
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
    
    #找出包含指定实体的最小群组或组件
    def find_min_group_by_ent(ent)
        
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
    

     #找出墙面与面
    def find_wall_faces
        @attributeHashList.each{|item|
                if item["name"].to_s == "墙"  #
                    if item["ent"].typename == "Group"
                        item["ent"].entities.each{|item2|
                            if item2.typename == "Face" && !item2.normal.samedirection?([0,0,1]) && !item2.normal.samedirection?([0,0,-1])
                                @wallFaceList << item2   
                            end 
                        }   
                    elsif item["ent"].typename == "ComponentInstance"
                        item["ent"].definition.entities.each{|item2|
                            if item2.typename == "Face" && !item2.samedirection?([0,0,1]) && !item2.samedirection?([0,0,-1])
                                @wallFaceList << item2   
                            end 
                        }   
                    elsif item["ent"].typename == "Face"
                        @wallFaceList << item
                    end
                # else
                #     if item["ent"].typename == "Group"
                #         item["ent"].entities.each{|item2|
                #             if item2.typename == "Face" 
                #                 @wallFaceList << item2   
                #             end 
                #         }   
                #     elsif item["ent"].typename == "ComponentInstance"
                #         item["ent"].definition.entities.each{|item2|
                #             if item2.typename == "Face" 
                #                 @wallFaceList << item2   
                #             end 
                #         }   
                #     elsif item["ent"].typename == "Face"
                #         @wallFaceList << item
                #     end
                end
            }
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

    def show_mm_points(points)
        points_2 = []
        points.each{|item|
            points_2 << [item[0].to_mm,item[1].to_mm,item[2].to_mm]
        }
        p points_2
    end

    #画线
    def draw_line_by_segments(segemnts,type)
        segemnts.each{|items|
            line = @ents.add_line items[0], items[1]
            if type == "hot"
                line.material = "red" if !line.nil?
            end 
        }
    end 

    def draw_line_by_points(points)
        group1 = @ents.add_group
        ent1 = group1.entities
        points.each_cons(2){|items|
           line = ent1.add_line items[0], items[1]
        }
        group1
    end 
end 

# FengPipeLine.new.run([[0,0,2800.mm],[8321.mm,7892.mm,2800.mm]], [0,0,1], 2800.mm, 300.mm)
