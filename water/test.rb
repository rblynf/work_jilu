 
	  def definition
        return @definition if @definition
        @definition = @model.definitions.add("__TEMP__(#{rand(100000)})")
        @definition.entities.add_cpoint(ORIGIN).hidden= true
        @definition
      end	

		#测试， 画几个带属性的组或组件
		@model = Sketchup.active_model
        @ents = @model.entities
		
		
  #       group1 = @ents.add_group 
  #       group1.set_attribute('attributedictionaryname', 'name', '墙')
  #       face1_g1 = group1.entities.add_face([5030.mm,4020.mm,0.mm],[5330.mm,4020.mm,0.mm],[5330.mm,2140.mm,0.mm],[5030.mm,2140.mm,0.mm],[5030.mm,4020.mm,0.mm])
		# face1_g1.reverse!
		# face1_g1.pushpull 60
       
		# group2 = @ents.add_group 
  #       group2.set_attribute('attributedictionaryname', 'name', '墙')
  #       face1_g2 = group2.entities.add_face([5030.mm,1020.mm,0.mm],[5330.mm,1020.mm,0.mm],[5330.mm,-234.mm,0.mm],[5030.mm,-234.mm,0.mm],[5030.mm,1020.mm,0.mm])
		# face1_g2.reverse!
		# face1_g2.pushpull 60
	   
		# # group3 = definition.entities.add_group
		# group3 = @ents.add_group 
  #       group3.set_attribute('attributedictionaryname', 'name', '墙')
  #       face1_g3 = group3.entities.add_face([1720.mm,520.mm,0.mm],[1720.mm,3110.mm,0.mm],[-1620.mm,3110.mm,0.mm],[-1620.mm,1734.mm,0.mm],[-1320.mm,1734.mm,0.mm],[-1320.mm,2734.mm,0.mm],[1420.mm,2710.mm,0.mm],[1420.mm,520.mm,0.mm],[1720.mm,520.mm,0.mm])
		# face1_g3.reverse!
		# face1_g3.pushpull 60
		
		
		# group4 = @ents.add_group 
  #       group4.set_attribute('attributedictionaryname', 'name', '墙')
  #       face1_g4 = group4.entities.add_face([1720.mm,-550.mm,0.mm],[1420.mm,-550.mm,0.mm],[1420.mm,-3420.mm,0.mm],[1720.mm,-3420.mm,0.mm],[1720.mm,-550.mm,0.mm])
		# face1_g4.reverse!
		# face1_g4.pushpull 60
		
		

		# group8 = definition.entities.add_group
		# group8 = @ents.add_group 
  #       group8.set_attribute('attributedictionaryname', 'name', '墙')
  #       face1_g8 = group8.entities.add_face([-120.mm,-1480.mm,0.mm],[-1320.mm,-1480.mm,0.mm],[-1320.mm,-580.mm,0.mm],[-1620.mm,-580.mm,0.mm],[-1620.mm,-3420.mm,0.mm],[-1320.mm,-3420.mm,0.mm],[-1320.mm,-1780.mm,0.mm],[-120.mm,-1780.mm,0.mm],[-120.mm,-1480.mm,0.mm])
		# face1_g8.reverse!
		# face1_g8.pushpull 60
		
		# group10 = @ents.add_group 
  #       group10.set_attribute('attributedictionaryname', 'name', '墙')
  #       face1_g10 = group10.entities.add_face([6000.mm,6000.mm,0.mm],[8000.mm,6000.mm,0.mm],[8000.mm,6300.mm,0.mm],[6000.mm,6300.mm,0.mm],[6000.mm,6000.mm,0.mm])
		# face1_g10.reverse!
		# face1_g10.pushpull 60
		
		
	  
        
		group5 = @ents.add_group 
        group5.set_attribute('attributedictionaryname', 'name', '洗手盆')
        # group5.set_attribute('attributedictionaryname', 'high', '550')
		group5.set_attribute('attributedictionaryname', 'coldAndHot', '1')
        group5.set_attribute('attributedictionaryname', 'ql', '0.1')  
        group5.set_attribute('attributedictionaryname', 'supplyFittingName', '感应水嘴') 
        face1_g5 = group5.entities.add_face([1600.mm,4300.mm,800.mm],[1600.mm,4100.mm,800.mm],[1800.mm,4100.mm,800.mm],[1800.mm,4300.mm,800.mm],[1600.mm,4300.mm,800.mm])
		face1_g5.pushpull 4
		
		
		group6 = @ents.add_group 
        group6.set_attribute('attributedictionaryname', 'name', '蹲式大便器')
        # group6.set_attribute('attributedictionaryname', 'high', '550')
		# group6.set_attribute('attributedictionaryname', 'coldAndHot', '1')
        group6.set_attribute('attributedictionaryname', 'ql', '0.1')    
        group6.set_attribute('attributedictionaryname', 'supplyFittingName', '冲洗水箱浮球阀') 
        face1_g6 = group6.entities.add_face([100.mm,4300.mm,800.mm],[100.mm,4100.mm,800.mm],[300.mm,4100.mm,800.mm],[300.mm,4300.mm,800.mm],[100.mm,4300.mm,800.mm])
		face1_g6.pushpull 4
		
		group7 = @ents.add_group 
        group7.set_attribute('attributedictionaryname', 'name', '淋浴器')
        # group7.set_attribute('attributedictionaryname', 'high', '1150')
		group7.set_attribute('attributedictionaryname', 'coldAndHot', '1')
        group7.set_attribute('attributedictionaryname', 'ql', '0.15')    #   
        group7.set_attribute('attributedictionaryname', 'supplyFittingName', '混合阀') 
        face1_g7 = group7.entities.add_face([130.mm,150.mm,450.mm],[130.mm,-150.mm,450.mm],[-170.mm,-150.mm,450.mm],[-170.mm,150.mm,450.mm],[130.mm,150.mm,450.mm])
		face1_g7.pushpull 4
		
		group9 = @ents.add_group 
        group9.set_attribute('attributedictionaryname', 'name', '小便器')
		group9.set_attribute('attributedictionaryname', 'coldAndHot', '0')
        group9.set_attribute('attributedictionaryname', 'ql', '0.1')  
        group9.set_attribute('attributedictionaryname', 'supplyFittingName', '自动冲洗水箱进水阀') 
        face1_g9 = group9.entities.add_face([-1010.mm,-1020.mm,1000.mm],[-1010.mm,-720.mm,1000.mm],[-710.mm,-720.mm,1000.mm],[-710.mm,-1020.mm,1000.mm],[-1010.mm,-1020.mm,1000.mm])
		face1_g9.pushpull 4
		
		
        instance1 = @ents.add_group
        instance1.set_attribute('attributedictionaryname', 'name', '洗脸盆')
		instance1.set_attribute('attributedictionaryname', 'coldAndHot', '1')
		# instance1.set_attribute('attributedictionaryname', 'high', '150')
        instance1.set_attribute('attributedictionaryname', 'ql', '0.15')      
        instance1.set_attribute('attributedictionaryname', 'supplyFittingName', '混合水嘴') 
        face1_i1 = instance1.entities.add_face([-1010.mm,150.mm,450.mm],[-1010.mm,-150.mm,450.mm],[-710.mm,-150.mm,450.mm],[-710.mm,150.mm,450.mm],[-1010.mm,150.mm,450.mm])
		face1_i1.reverse!
		face1_i1.pushpull 3
        
		instance2 = @ents.add_group
        instance2.set_attribute('attributedictionaryname', 'name', 'aa热水器')
        instance2.set_attribute('attributedictionaryname', 'coldAndHot', '1')
		# instance2.set_attribute('attributedictionaryname', 'high', '1200')
        instance2.set_attribute('attributedictionaryname', 'ql', '0.4')      # 
        instance2.set_attribute('attributedictionaryname', 'supplyFittingName', '洒水栓') 
        face1_i2 = instance2.entities.add_face([-600.mm,4300.mm,800.mm],[-600.mm,4100.mm,800.mm],[-400.mm,4100.mm,800.mm],[-400.mm,4300.mm,800.mm],[-600.mm,4300.mm,800.mm])
		face1_i2.reverse!
		face1_i2.pushpull 3



		
		
		
