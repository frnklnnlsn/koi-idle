extends Node2D



func _ready():
	var array = [100,-400]
	iterate(array)
	#instantiate_test()
	
	
	
	
	
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func instantiate_test():
	var scene1 = preload("res://SandBox/seperated script test/scenes/Instnace_test.tscn").instantiate()
	var scene2 = preload("res://SandBox/seperated script test/scenes/Instnace_test.tscn").instantiate()
	var MyClass = load("res://SandBox/seperated script test/scripts/myclass.gd")
	var instance1 = MyClass.new()
	var instance2 = MyClass.new()
	scene1.add_child(instance1)
	scene2.add_child(instance2)
	add_child(scene1)
	add_child(scene2)
	var child_node = scene1.get_child(0)
	child_node.change_parent_position(200)
	var child_node2 = scene2.get_child(0)
	child_node2.change_parent_position(-200)

func iterate(array:Array): ## of int x
	for i in array:
		var scene1 = preload("res://SandBox/seperated script test/scenes/Instnace_test.tscn").instantiate()
		var MyClass = load("res://SandBox/seperated script test/scripts/myclass.gd")
		var instance1 = MyClass.new()
		scene1.add_child(instance1)
		add_child(scene1)
		var child_node = scene1.get_child(0)
		child_node.change_parent_position(i)









#var MyClass = load("res://SandBox/seperated script test/scripts/myclass.gd")
	#var instance1 = MyClass.new()
	#var instance2 =  MyClass.new()
	#var check
	#assert(instance1.get_script() == MyClass)
	#assert(instance2.get_script() == MyClass)
	#
	#instance1.Booling = true
	##print(instance1.Booling)
	#instance2.Booling = false
	##print(instance1.Booling)
	##print(instance2.Booling)
