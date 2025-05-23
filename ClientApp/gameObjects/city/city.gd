extends Node2D
class_name City

# Identifiers
var id:int

# UI
@onready var Camera:Camera2D = get_parent().get_parent().get_node("%camera+static ui")
@onready var UI:Panel = get_node("%UI")
@onready var UI_name:Label = get_node("%name")
@onready var UI_ownerID:Label = get_node("%ownerID")
@onready var UI_population:Label = get_node("%population")
@onready var UI_stockpile:Label = get_node("%stockpile")
@onready var UI_TTP:Label = get_node("%TTP")
@onready var UI_display:Panel = get_node("%Display")
@onready var UI_nameDis:Label = get_node("%nameDisplay")
@onready var UI_popDis:Label = get_node("%popDisplay")
@onready var UI_taxDis:Label = get_node("%taxDIsplay")

# Nodes
@onready var cityLimits:Polygon2D = get_node("%CityLimitsPoly")
@onready var master:Master = get_parent().get_parent()

# Signaling
signal production_tick(city:City)
signal taxes_collected(taxes:int)

# Population constants
var initialPopulation:int = 1000
var maxPopulation:int = 500000
var growthRate:float = .02 

# Production
var population:int = initialPopulation
var productionTime:int = 1800 # 30 minutes
var productionCountdown:int = productionTime
var stockpile:float = 0
var maxStockpile:int = 150
var inputs:Resources = Resources.new()

# Construction
var constructionCost:Resources = Resources.new()
var cc_money = 15000
var cc_food = 5000
var cc_building_materials = 7500

func buildNumString(num:float) -> String:
	if(int(num / 100000) > 0): return(str(int(num) / 1000) + "k")
	elif (int(num / 10000) > 0): return(str(int(num / 100) / 10.0) + "k")
	elif (int(num / 1000) > 0): return(str(int(num / 10) / 100.0) + "k")
	else: return(str(num))

func calculateFoodUsage(population:int) -> int:
	return floor(((population * .001) - .00006*pow(population, 1.2) + 5) / 3)

func calculateCGUsage(population:int) -> int:
	return floor(calculateFoodUsage(population) * .4)

func calculateTaxProduction(population:int) -> int:
	return floor(calculateFoodUsage(population) * 8)

func growPopulation(modifier:float) -> void:
	# Update UI according to modifier
	if (modifier < 0): UI_popDis.add_theme_color_override("font_color", Color.RED)
	elif (modifier < 1): UI_popDis.add_theme_color_override("font_color", Color.YELLOW)
	else: UI_popDis.add_theme_color_override("font_color", Color.WHITE)
	
	# Calculate and update new population
	if (modifier < 0): population += (growthRate * population) * modifier
	else: population += (growthRate * population)* max(0, 1-(population/maxPopulation)) * modifier
	set_meta("population", population)

# Add production to the extractor and increase stockpile when necessary
func doProductionTick(time:int) -> void:
	#print("Doing tick on extractor:" + name)
	productionCountdown -= time
	if(productionCountdown <= 0): # Production cycle completed
		production_tick.emit(self)
		productionCountdown = productionTime + productionCountdown
		
		# Update City limits - modified log scale giving values between ~2 and ~4.75
		cityLimits.scale[0] = max(2, (0.69 * (log(population) / log(10)) + (0.0000018 * population) - 0.1))
		cityLimits.scale[1] = cityLimits.scale[0]
		
		# Update inputs
		inputs.food = calculateFoodUsage(population)
		if (population > 100000): inputs.consumer_goods = calculateCGUsage(population)
		else: inputs.consumer_goods = 0
	
	# Update UI
	UI_population.text = "Population: " + str(get_meta("population"))
	UI_stockpile.text = "Taxes: " + str(calculateTaxProduction(population) * stockpile)
	UI_TTP.text = "TTP: " + str(productionCountdown)
	
	UI_popDis.text = buildNumString(get_meta("population"))
	UI_taxDis.text = buildNumString(calculateTaxProduction(population) * stockpile)
	if(stockpile == maxStockpile): UI_taxDis.add_theme_color_override("font_color", Color.RED)
	return

# Check if the player has enough resources to supply the city
func checkResources(playerResources:Resources) -> int:
	var temp:Resources = Resources.new()
	temp.combine(self.inputs.negateNoMod())
	temp.combine(playerResources)
	if temp.food < 0 && temp.consumer_goods < 0: return 3
	if temp.food < 0: return 1
	if temp.consumer_goods < 0: return 2
	else: return 0

func _ready() -> void:
	# Set construction costs
	constructionCost.money = cc_money
	constructionCost.food = cc_food
	constructionCost.building_materials = cc_building_materials
	
	# Hide UI and update values
	UI.visible = false
	UI_name.text = name
	UI_nameDis.text = name
	UI_ownerID.text = "OwnerID: " + str(get_meta("ownerID"))
	
	# Get population
	population = get_meta("population")
	
	# Update inputs
	inputs.food = calculateFoodUsage(population)
	if (population > 100000): inputs.consumer_goods = calculateCGUsage(population)
	else: inputs.consumer_goods = 0
	pass

func _process(delta: float) -> void:
	# Make UI follow cursor if the UI isn't hidden
	if UI.visible == true:
		# Update scale
		UI.scale[0] = 1/Camera.zoom[0]
		UI.scale[1] = UI.scale[0]
		
		# Update position
		var m_pos:Vector2 = get_local_mouse_position()
		UI.position[0] = m_pos[0] + (12 * UI.scale[0])
		UI.position[1] = m_pos[1] - (0  * UI.scale[0])
	pass

func _on_city_inner_coll_mouse_entered() -> void:
	UI.visible = true
	return

func _on_city_inner_coll_mouse_exited() -> void:
	UI.visible = false
	return

# On left click - collect taxes
func _on_city_inner_coll_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if(Input.is_action_just_pressed("LMB")):
		if(master.curr_player.id == get_meta("ownerID")):
			# Send taxes to masterScene and empty stockpile
			taxes_collected.emit(calculateTaxProduction(population) * stockpile)
			stockpile = 0
			
			# Update UI
			UI_stockpile.text = "Taxes: 0"
			UI_taxDis.text = "0"
			UI_taxDis.add_theme_color_override("font_color", Color.WHITE)
		else: master.staticUI.notify("Cannot collect taxes from another player's city")
	return
