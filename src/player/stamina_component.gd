class_name StaminaComponent
extends Node
## StaminaComponent - Manages stamina for sprinting, attacks, blocking, and dashing

signal stamina_changed(current: float, maximum: float)
signal stamina_depleted()
signal stamina_recovered()

@export var max_stamina: float = 100.0
@export var regen_rate: float = 30.0  # Per second - fast recovery
@export var regen_delay: float = 0.4  # Seconds after use before regen starts - short delay

var current_stamina: float = 100.0
var regen_cooldown: float = 0.0
var is_depleted: bool = false

func _ready() -> void:
	current_stamina = max_stamina

func _physics_process(delta: float) -> void:
	if regen_cooldown > 0:
		regen_cooldown -= delta
	elif current_stamina < max_stamina:
		current_stamina = min(current_stamina + regen_rate * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

		if is_depleted and current_stamina >= max_stamina * 0.3:
			is_depleted = false
			stamina_recovered.emit()

func use(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		regen_cooldown = regen_delay
		stamina_changed.emit(current_stamina, max_stamina)

		if current_stamina <= 0:
			is_depleted = true
			stamina_depleted.emit()
		return true
	return false

func use_continuous(amount_per_second: float, delta: float) -> bool:
	var amount = amount_per_second * delta
	if current_stamina >= amount:
		current_stamina -= amount
		regen_cooldown = regen_delay
		stamina_changed.emit(current_stamina, max_stamina)

		if current_stamina <= 0:
			is_depleted = true
			stamina_depleted.emit()
		return true
	return false

func has_stamina(amount: float) -> bool:
	return current_stamina >= amount

# Alias for use() - for consistency with new combat system
func spend(amount: float) -> bool:
	return use(amount)

# Check if we can spend without actually spending
func can_spend(amount: float) -> bool:
	return current_stamina >= amount

func add(amount: float) -> void:
	current_stamina = min(current_stamina + amount, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)

	if is_depleted and current_stamina >= max_stamina * 0.3:
		is_depleted = false
		stamina_recovered.emit()

func get_percentage() -> float:
	return current_stamina / max_stamina

func reset() -> void:
	current_stamina = max_stamina
	regen_cooldown = 0.0
	is_depleted = false
	stamina_changed.emit(current_stamina, max_stamina)

func set_max_stamina(new_max: float) -> void:
	var percentage = get_percentage()
	max_stamina = new_max
	current_stamina = max_stamina * percentage
	stamina_changed.emit(current_stamina, max_stamina)
