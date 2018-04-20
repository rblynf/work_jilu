attr_value = null;

$(".btn_ok").click(function(){
	var param = get_attr();
	var params = JSON.stringify(param);
	window.location = "skp:save_attr@"+params; 
	window.location = "skp:mainWin@";
});
$(".btn_quit").click(function(){
	window.location = "skp:mainWin@";
});

function is_num(obj){
	if(isNaN(obj.value)){
		alert("请输入数字!");
		$(obj).focus();
		$(obj).val(obj.value);
	}
}

function back_light(){
	var param = get_setPage();
	var params = JSON.stringify(param);
	window.location = "skp:save_Set@"+params;
	window.location = "skp:attrSet@"+$("#sys_num").val();
}

function link_line(){
	var hash = {}
	var param2 = get_setPage();
	$.each(attr_value,function(i,obj){
		hash[i]=obj;
	});
	$.each(param2,function(i,obj){
		hash[i]=obj;
	});
	//alert(JSON.stringify(hash));
	window.location = "skp:link_tool@"+JSON.stringify(hash);
}

function close_lightSet(){
	window.location = "skp:ruby_cancle@";
}

/*设置页面的数据获取*/
function get_setPage(){
	var param = {
		"项目名称":$("#project_name").val(),
		"几点连线":$("#assign").val(),
		"离地高度":$("#distance1").val(),
		"离墙距离":$("#distance2").val(),
		"连线方向":$("#attachment_direction").val()
	}
	return param;
}

function get_attr(){
	var param ={
		// "离地高度":$("#distance1").val()
	}
	return param;
}

/*恢复数据*/
function set_data(param){
	var params = JSON.parse(param);
	$("#project_name").val(params["项目名称"]);
	$("#assign").val(params["几点连线"]);
	$("#distance1").val(params["离地高度"]);
	$("#distance2").val(params["离墙距离"]);
	$("#attachment_direction").val(params["连线方向"]);
}

function attr_data(param){
	var params = JSON.parse(param);
	// $("#distance1").val(params["离地高度"])
}



