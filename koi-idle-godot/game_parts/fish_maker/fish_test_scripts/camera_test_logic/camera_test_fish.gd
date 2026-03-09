extends Node

@export var fish_res:fish_conf

@onready var fish = %fish

@onready var camera_2d = $SubViewportContainer/SubViewport/Camera2D

### zoom selector
@onready var camera_zoom_scroller = %camera_zoom
### number of cxolor selector
@onready var number_scale = %number_scale
### name edit box
@onready var name_edit = %name_edit
### the seed line edit,reads out the seed value
@onready var seed_line = %seed_line
### seed slider, a slider so you can edit seed value
@onready var seed_slider = %seed_slider

### frequecy line edit, frequency slider, noise option button
@onready var frequency_line = %frequency_line
@onready var frequency_slider = %frequency_slider
@onready var noise_type = %noise_type

### fish resource popup
@onready var fish_resources_pop_up = %"Fish Resources pop up"
@onready var button_container = %button_container
@onready var folder_button = %folder_button
@onready var sub_folder:String = "default"

### color picker grid
@onready var color_grid = $"Control/VBoxContainer/save and color box/color_grid"
### the color picker boxes
@onready var color_1_box = %color_1_box
@onready var color_2_box = %color_2_box
@onready var color_3_box = %color_3_box
@onready var color_4_box = %color_4_box
@onready var color_5_box = %color_5_box
### the color picker buttons
@onready var color_picker_1 = %Color_picker1
@onready var color_picker_2 = %Color_picker2
@onready var color_picker_3 = %Color_picker3
@onready var color_picker_4 = %Color_picker4
@onready var color_picker_5 = %Color_picker5
### the color picker sliders (defines the offsets and order)
@onready var color_picker_1_slider = %color_picker_1_slider
@onready var color_picker_2_slider = %color_picker_2_slider
@onready var color_picker_3_slider = %color_picker_3_slider
@onready var color_picker_4_slider = %color_picker_4_slider
@onready var color_picker_5_slider = %color_picker_5_slider

### var that are passed on to the resource
@onready var num_of_color:int 
@onready var fish_name:String

@onready var color_1:Color
@onready var color_2:Color
@onready var color_3:Color
@onready var color_4:Color
@onready var color_5:Color


### flag var
var let_me_type_seed = false
var let_me_type_freq = false

func _ready():
	color_2_box.visible = false
	color_3_box.visible = false
	color_4_box.visible = false
	color_5_box.visible = false
	
### pop up stuff, currently jank, but sets first index as open folder
	fish_resources_pop_up.visible = false
	populate_folder_button()
	var partial_folder_path = "res://game_parts/fish_maker/resource_etc/fish_template_resources/"
	var list = DirAccess.get_directories_at(partial_folder_path)
	var sub_folder = list[0]
	var dict = create_res_dict(partial_folder_path,sub_folder)
	create_buttons_from_dict(dict)


func _process(delta):
	adjust_zoom()
	var num = number_scale.value
	get_color_pickers(num)
	update_fish_colors()
	seed_process()
	frequency_process()
	
	#test()


func test():
	#noise_type.select(3)
	#print(noise_type.get_item_text(2))
	##print(print)
	pass


func adjust_zoom() ->void:
	if camera_zoom_scroller:
		var zoom_value = camera_zoom_scroller.value
		var zoom:Vector2 = Vector2(zoom_value,zoom_value)
		camera_2d.zoom = zoom


func show_seed_value():
	var seed = float(seed_line.text)
	pass


func get_color_pickers(num) ->void:
	if num == 1:
		color_1_box.visible = true
		color_2_box.visible = false
		color_3_box.visible = false
		color_4_box.visible = false
		color_5_box.visible = false
	if num == 2:
		color_1_box.visible = true
		color_2_box.visible = true
		color_3_box.visible = false
		color_4_box.visible = false
		color_5_box.visible = false
	if num == 3:
		color_1_box.visible = true
		color_2_box.visible = true
		color_3_box.visible = true
		color_4_box.visible = false
		color_5_box.visible = false
	if num == 4:
		color_1_box.visible = true
		color_2_box.visible = true
		color_3_box.visible = true
		color_4_box.visible = true
		color_5_box.visible = false
	if num == 5:
		color_1_box.visible = true
		color_2_box.visible = true
		color_3_box.visible = true
		color_4_box.visible = true
		color_5_box.visible = true


func get_color_offsets():
### make array of all box nodes
	var box_1 = color_1_box
	var box_2 = color_2_box
	var box_3 = color_3_box
	var box_4 = color_4_box
	var box_5 = color_5_box
	
	var box_array = [
		color_1_box,
		color_2_box,
		color_3_box,
		color_4_box,
		color_5_box,
		]
### make an array of slider values
	var slider_1 = color_picker_1_slider.value
	var slider_2 = color_picker_2_slider.value
	var slider_3 = color_picker_3_slider.value
	var slider_4 = color_picker_4_slider.value
	var slider_5 = color_picker_5_slider.value
	
	var slider_value_array = [
		slider_1,
		slider_2,
		slider_3,
		slider_4,
		slider_5,
		]

	slider_value_array.sort()
### for each vbox in the box_array set slider variable = to the 
### first child of the color_#_box (0)
### hold value = slider value
### for slider in array of all sliders
### if slider value is = to the hold value,
### get index, and move child,

### this way I can connect the values of the sorted array
### with the actual nodes they represent, 
### Im sure this could be done cleaner
	for vbox in box_array:
		var slider = vbox.get_child(0)
		var hold_value = slider.value
		for slider_value in slider_value_array:
			if hold_value == slider_value:
				var index = slider_value_array.bsearch(slider_value)
				color_grid.move_child(vbox, index)
	pass


func _on_save_button_pressed():
	var partial_path = "res://game_parts/fish_maker/resource_etc/fish_template_resources/"
	var directory = partial_path + sub_folder + "/"
	var file_name = str(fish_name + ".tres")
	var file_path = directory + file_name
	var data = create_new_fish_resource()
	var err = ResourceSaver.save(data,file_path)
	print("this is the err: " + str(err))
	print("this is the file path: " + file_path)


func create_buttons_from_dict(dictionary):
	for key in dictionary:
		var new_button = Button.new()
		new_button.alignment = 0
		new_button.text = key
		button_container.add_child(new_button)
		
		#new_button.pressed.connect(func load_fish_res(key,dictionary): )
		new_button.pressed.connect(load_fish_res.bind(key,dictionary))


func remove_child_buttons(parent:VBoxContainer):
	var size = parent.get_child_count()
	print("this is the number of children nodes: " + str(size))
	for button in range(size):
		print("kill")
		var child = parent.get_child(button)
		child.queue_free()

func load_fish_res(key, dictionary):
	var new_res = dictionary[key]
	var body = fish.get_child(1)
	name_edit.text = new_res.name
	noise_type.select(new_res.noise_type_index)
	body.update_noise_type(new_res.noise_type_index)
	seed_slider.value = new_res.seed
	seed_line.text = str(new_res.seed)
	body.update_seed(new_res.seed)
	frequency_slider.value = new_res.frequency
	frequency_line.text = str(new_res.frequency)
	body.update_frequency(new_res.frequency)
	
	
	
	set_slider_values_for_color(new_res)
	set_color_picker_values(new_res)


func set_slider_values_for_color(new_res):
	var num_of_color_box = new_res.colors.size()
	number_scale.value = num_of_color_box
	print(num_of_color_box)
	if num_of_color_box == 1:
		print("one color")
		color_picker_1_slider.value = new_res.offsets[0]
		print(new_res.offsets)
	if num_of_color_box == 2:
		print("two color")
		color_picker_1_slider.value = new_res.offsets[0]
		color_picker_2_slider.value = new_res.offsets[1]
	if num_of_color_box == 3:
		print("three color")
		color_picker_1_slider.value = new_res.offsets[0]
		color_picker_2_slider.value = new_res.offsets[1]
		color_picker_3_slider.value = new_res.offsets[2]
	if num_of_color_box == 4:
		print("four color")
		color_picker_1_slider.value = new_res.offsets[0]
		color_picker_2_slider.value = new_res.offsets[1]
		color_picker_3_slider.value = new_res.offsets[2]
		color_picker_3_slider.value = new_res.offsets[3]
	if num_of_color_box == 5:
		print("five color")
		color_picker_1_slider.value = new_res.offsets[0]
		color_picker_2_slider.value = new_res.offsets[1]
		color_picker_3_slider.value = new_res.offsets[2]
		color_picker_3_slider.value = new_res.offsets[3]
		color_picker_3_slider.value = new_res.offsets[4]
	
	#seed_line.text = new_res.seed
	#body.name = new_res.name
	#body.offsets = new_res.offsets
	#body.colors = new_res.colors
	#body.noise_type_index = new_res.noise_type_index
	#body.seed = new_res.seed
	#body.frequency = new_res.frequency


func set_color_picker_values(new_res):
	var num_of_color_box = new_res.colors.size()
	if num_of_color_box == 1:
		color_picker_1.color = new_res.colors[0]
	if num_of_color_box == 2:
		color_picker_1.color = new_res.colors[0]
		color_picker_2.color = new_res.colors[1]
	if num_of_color_box == 3:
		color_picker_1.color = new_res.colors[0]
		color_picker_2.color = new_res.colors[1]
		color_picker_3.color = new_res.colors[2]
	if num_of_color_box == 4:
		color_picker_1.color = new_res.colors[0]
		color_picker_2.color = new_res.colors[1]
		color_picker_3.color = new_res.colors[2]
		color_picker_4.color = new_res.colors[3]
	if num_of_color_box == 5:
		color_picker_1.color = new_res.colors[0]
		color_picker_2.color = new_res.colors[1]
		color_picker_3.color = new_res.colors[2]
		color_picker_4.color = new_res.colors[3]
		color_picker_5.color = new_res.colors[4]


func populate_folder_button():
	var folder_path = "res://game_parts/fish_maker/resource_etc/fish_template_resources/"
	var list = DirAccess.get_directories_at(folder_path)
	for folder in list:
		folder_button.add_item(folder)




func create_res_dict(partial_folder_path,sub_folder)-> Dictionary:
	var folder_path = partial_folder_path + sub_folder + "/"
	var resource_dict:Dictionary = {}
	var dir = DirAccess.open(folder_path)   
	dir.list_dir_begin()
	var file_name = dir.get_next() 
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = folder_path + "/" + file_name
			var res = load(full_path)
			if res:
				var name_key = file_name.get_basename()
				resource_dict[name_key] =res
		file_name = dir.get_next()
	dir.list_dir_end()
	return resource_dict


func create_new_fish_resource():
	var new_fish_res = fish_res.duplicate()
	var body = fish.get_child(1)
	new_fish_res.name = fish_name
	new_fish_res.offsets = body.offsets
	new_fish_res.colors = body.colors
	new_fish_res.noise_type_index = body.noise_type_index
	new_fish_res.frequency = body.frequency
	new_fish_res.seed = body.seed
	return new_fish_res


func update_fish_colors():
	var offset_array = get_offset_array()
	var colors_array = get_colors_array()
	var body:Line2D = fish.get_child(1)
	body.offsets = offset_array
	body.colors = colors_array

func get_offset_array():
	var offset_array:PackedFloat32Array = []
	for box in color_grid.get_children():
		if box.visible == true:
			var slider = box.get_child(0)
			var offset = slider.value
			offset_array.append(offset)
	return offset_array

func get_colors_array():
	var colors_array:PackedColorArray = []
	for box in color_grid.get_children():
		if box.visible == true:
			var color_picker = box.get_child(1)
			var color = color_picker.color
			colors_array.append(color)
	return colors_array

func _on_color_picker_1_slider_drag_ended(value_changed):
	get_color_offsets()
	print("changed")


func _on_color_picker_2_slider_drag_ended(value_changed):
	get_color_offsets()
	print("changed")


func _on_color_picker_3_slider_drag_ended(value_changed):
	get_color_offsets()
	print("changed")


func _on_color_picker_4_slider_drag_ended(value_changed):
	get_color_offsets()
	print("changed")


func _on_color_picker_5_slider_drag_ended(value_changed):
	get_color_offsets()
	print("changed")

### seed selection section
func seed_process() -> void:
	var seed = set_seed_from_slider()
	send_seed_to_fish(seed)


func send_seed_to_fish(seed):
	if seed:
		var body = fish.get_child(1)
		body.seed = seed

func _on_seed_line_text_submitted(new_text):
	var seed = float(new_text)
	seed_slider.value = seed
	send_seed_to_fish(seed)


func set_seed_from_slider():
	if let_me_type_seed == false:
		var seed = seed_slider.value
		seed_line.text = str(seed)
		return seed


func _on_seed_line_focus_entered():
	let_me_type_seed = true


func _on_seed_line_focus_exited():
	let_me_type_seed = false

### frequency, noise type section
func _on_frequency_line_focus_entered():
	let_me_type_freq = true


func _on_frequency_line_focus_exited():
	let_me_type_freq = false


func _on_frequency_line_text_submitted(new_text):
	var freq = float(new_text)
	frequency_slider.value = freq
	send_freq_to_fish(freq)


func set_freq_from_slider():
	if let_me_type_freq == false:
		var freq = frequency_slider.value
		frequency_line.text = str(freq)
		return freq


func send_freq_to_fish(freq):
	if freq:
		var body = fish.get_child(1)
		body.frequency = freq


func frequency_process() -> void:
	var freq = set_freq_from_slider()
	send_freq_to_fish(freq)


func _on_noise_type_item_selected(index):
	var body = fish.get_child(1)
	body.noise_type_index = index

### name edit stuff
func _on_name_edit_text_submitted(new_text):
	fish_name = str(new_text)


func _on_name_edit_focus_exited():
	if name_edit.text:
		fish_name = str(name_edit.text)
	pass # Replace with function body.


func _on_open_pressed():
	fish_resources_pop_up.visible = true


func _on_exit_pressed():
	fish_resources_pop_up.visible = false


func _on_folder_button_item_selected(index):
	var partial_folder_path = "res://game_parts/fish_maker/resource_etc/fish_template_resources/"
	var list = DirAccess.get_directories_at(partial_folder_path)
	sub_folder = list[index]
	var dict = create_res_dict(partial_folder_path,sub_folder)
	remove_child_buttons(button_container)
	create_buttons_from_dict(dict)
