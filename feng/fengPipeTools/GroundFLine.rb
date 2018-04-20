module GroundFLine
	class MyFLine
		def initialize
			# 编码
			@dir = File.dirname(__FILE__).encode("UTF-8")
			@dirname = File.dirname(__FILE__).encode("UTF-8")
			@@dialog = UI::WebDialog.new("风管连线工具", true, "连线", 900, 700, 140, 250, true)
			
			# 导入HTML文件
			@@dialog.set_url (@dirname+"/UI/html/main.html")

			#属性窗口
			@@dialogDng = UI::WebDialog.new("连线设置", true, "parme", 576.mm, 115.mm, 150, 150, true)
			@@dialogDng.set_url (@dirname+"/UI/html/index.html")
		
			#关闭窗口触发
			@@dialog.set_on_close {
			  if @@dialog.visible?
				 cancel = "show_aaa()"
				 @@dialog.execute_script(cancel)
			  end
			  # 关闭窗口
			  if @@dialogDng.visible?
				 show_cancel = "show_cancel()"
				 @@dialogDng.execute_script(show_cancel)
			  end
			}
			
			#显示小窗口
			@@dialogDng.add_action_callback('mainWin') { |dialogDng, params|
				@@dialog.show{
					aFile = File.new(File.join(@dirname+"/data/set.txt"),"r:UTF-8")
					json = aFile.read
					show_win = "set_data('#{json}')"
					@@dialog.execute_script(show_win)
					# 主窗口 带全部属性值
					aFile1 = File.new(File.join(@dirname+"/data/attr.txt"),"r:UTF-8")
					json1 = aFile1.read
					@@dialog.execute_script("attr_value=#{json1}")

				}
				@@dialogDng.close
			}
			
			@@dialog.add_action_callback('set_back'){|dialog,params|

			}

			@@dialogDng.add_action_callback('attr_back'){|dialog,params|

			}
			@@dialog.add_action_callback('link_tool'){|dialog,params|
				Sketchup.active_model.select_tool Link_Tool.new(JSON.parse(params))
			}
			#显示属性窗口
			@@dialog.add_action_callback('attrSet') { |dialog, params|
				aFile = File.open(File.join(@dirname+"/data/attr.txt"),"r:UTF-8")
				json = aFile.read
				@@dialogDng.show{
					show_win = "attr_data('#{json}')"
					@@dialogDng.execute_script(show_win)
				}
				@@dialog.close
			}

			#属性界面 参数保存
			@@dialogDng.add_action_callback('save_attr') { |dialogDng, params|
			
				aFile = File.open(File.join(@dirname + "/data/attr.txt"),"w+")
				if aFile
					aFile.syswrite(params)
				end
				aFile.close
			}

			#设置界面 参数保存
			@@dialog.add_action_callback('save_Set') { |dialog, params|
				aFile = File.open(File.join(@dirname + "/data/set.txt"),"w+")
				if aFile
					aFile.syswrite(params)
				end
				aFile.close
			}

			@@dialog.add_action_callback('ruby_cancle') { |dialog|
			  dialog.close
			}
		end 
		
		def self.show()
			@@dialog.show if @@dialog
		end
		
	end
end