scene = nil
player = nil
main_camera = nil
g_game_config = {
	ground_height = 64,	-- Height of the first ground pixel
}
state = nil

function _init()
	set_game_state(title_state)
end

function _update()
	if state ~= nil then
		state.update(state)
	end
	
	-- @DEBUG g_log.log("CPU: "..stat(1))
end

function _draw()
	cls()

	if state ~= nil then
		state.draw(state)
	end

	-- Draw debug log
	g_log.render()
	g_log.clear()
end

--
-- Sets the active game state
--
function set_game_state(game_state)
	if state ~= nil and state.exit then
		state.exit(self)
	end

	state = game_state
	state.enter(self)
end

-- 
-- Encapsulates the title screen
--
title_state = {
	enter = function(self)
	end,

	update = function(self)
		if btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5) then
			set_game_state(ingame_state)
		end
	end,

	draw = function(self)
		-- Draw main title window
		camera()
		clip()

		map(0, 0, 0, 0, 128, 128) -- draw the whole map and let the clipping region remove unnecessary bits

		rectfill(12, 30, 116, 76, 6)
		rectfill(14, 32, 114, 74, 3)
		color(7)

		local line_height = 10
		local print_y = 40
		print("weed.", 56, print_y)
		print_y += line_height

		print("by pixel.pistol.games", 22, print_y)
		print_y += line_height

		print("press any key to begin", 20, print_y)
	end,

	exit = function(self)

	end
}

--
-- Encapsulates the ingame state
--
ingame_state = {
	enter = function(self)
		scene = {}

		-- Make the camera
		main_camera = make_camera(0, 0, 128, 128, 0, 0)

		-- clouds
		g_cloud_generator.init(180)
		g_cloud_generator.generate_cloud()

		-- Weeds
		g_weed_generator.init(16, 32, 60) 
		g_weed_generator.generate_weed()

		-- Player
		local player_height = 8
		local player_start_x = 128 / 2 -- Middle of the screen
		local player_start_y = g_game_config.ground_height - player_height -- 1px above the ground
		player = make_player("player", player_start_x, player_start_y, 1, 2, 2)

		-- Weed highlighter
		make_weed_highlighter(player, 48)
	end,

	update = function(self)
		-- Process input
		player.velocity = make_vec2(0, 0)
		if btn(0) then
			player.velocity.x -= player.speed
		end

		if btn(1) then
			player.velocity.x += player.speed
		end

		if btnp(4) then
			player.pull_weed(player)
		end

		-- Update clouds.
		g_cloud_generator.update()

		-- Update weed generator
		g_weed_generator.update()

		-- Update game objects
		for game_obj in all(scene) do
			if (game_obj.update) then
				game_obj.update(game_obj)
			end
		end

		-- Check for game-over state
		if g_weed_generator.are_all_weeds_grown() then
			set_game_state(game_over_state)
		end
	end,

	draw = function(self)
		g_renderer.render()

		-- Draw score
		color(7)
		print("score: "..player.score.." ("..player.weeds_pulled.." weeds pulled)")
	end,

	exit = function(self)

	end
}

game_over_state = {
	enter = function(self)
		if not main_camera then
			main_camera = make_camera(0, 0, 128, 128, 0, 0)
		end

		if not player then
			player = {
				score = 0,
				weeds_pulled = 0,
			}
		end
	end,

	update = function(self)
		if btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5) then
			set_game_state(ingame_state)
		end

		-- Update game objects (mostly to keep animations running)
		for game_obj in all(scene) do
			if (game_obj.update) then
				game_obj.update(game_obj)
			end
		end
	end,

	draw = function(self)
		g_renderer.render()

		-- Draw game-over window
		camera()
		clip()

		rectfill(12, 30, 116, 86, 6)
		rectfill(14, 32, 114, 84, 3)
		color(7)

		local line_height = 10
		local print_y = 40
		print("game over!", 46, print_y)
		print_y += line_height

		print("final score: "..player.score, 34, print_y)
		print_y += line_height

		print("weeds pulled: "..player.weeds_pulled, 34, print_y)
		print_y += line_height

		print("press any key to restart", 16, print_y)
	end,

	exit = function(self)

	end
}

-- 
-- Game Object
--
function make_game_object(name, pos_x, pos_y)
	local game_obj = {
		position = make_vec2(pos_x, pos_y),
		name = name
	}
	return game_obj
end

--
-- Renderable maker.
--
function attach_renderable(game_obj, sprite)
	local renderable = {
		game_obj = game_obj,
		sprite = sprite,
		flip_x = false,
		flip_y = false,
		sprite_width = 1,
		sprite_height = 1,
		draw_order = 0,
		palette = nil
	}

	-- Default rendering function
	renderable.render = function(self, position)

		-- Set the palette
		if (self.palette) then
			-- Set colours
			for i = 0, 15 do
				pal(i, self.palette[i + 1])
			end

			-- Set transparencies
			for i = 17, #self.palette do
				palt(self.palette[i], true)
			end
		end

		-- Draw
		spr(self.sprite, position.x, position.y, self.sprite_width, self.sprite_height, self.flip_x, self.flip_y)

		-- Reset the palette
		if (self.palette) then
			pal()
			palt()
		end
	end

	-- Save the default render function in case the object wants to use it in an overridden render function.
	renderable.default_render = renderable.render

	game_obj.renderable = renderable;
	return game_obj;
end

--
-- Create a player
function make_player(name, start_x, start_y, sprite, speed, strength)
	local new_player = make_game_object(name, start_x, start_y)
	new_player.is_pulling_weed = false
	new_player.pulling_weed_elapsed = 0
	new_player.score = 0
	new_player.weeds_pulled = 0
	new_player.velocity = make_vec2(0, 0)

	-- Animations
	local player_anims = {
		idle = { 1 },
		pull_weed = { 2, 1 },
		walk = { 3, 4 }
	}

	attach_anim_spr_controller(new_player, 4, player_anims, "idle", 0)

	-- Game stats
	new_player.speed = speed
	new_player.strength = strength
	attach_renderable(new_player, sprite)
	new_player.renderable.draw_order = 1	-- Draw player after other in-game objects so he appears in front of weeds

	-- Pull a weed
	new_player.pull_weed = function(self)
		local center = self.position.x + (8 / 2)	-- Hardcoded to player width of 8px
		local column = g_weed_generator.pixel_to_column(center)
		local weed = g_weed_generator.get_weed(column)

		if weed ~= nil and not is_weed_fully_grown(weed) then
			pull_weed(weed, self.strength, self)
		end

		set_anim_spr_animation(self.anim_controller, "pull_weed")
		self.is_pulling_weed = true
		self.pulling_weed_elapsed = 0
	end

	-- Update player
	new_player.update = function (self)
		if self.is_pulling_weed then
			self.pulling_weed_elapsed += 1

			local pulling_weed_duration = #self.anim_controller.animations['pull_weed'] * self.anim_controller.frames_per_cell
			if self.pulling_weed_elapsed > pulling_weed_duration then
				self.is_pulling_weed = false
				set_anim_spr_animation(self.anim_controller, 'idle')
			end
		else
			self.position += self.velocity
			if self.velocity.x < 0 then
				self.renderable.flip_x = true
				set_anim_spr_animation(self.anim_controller, 'walk')
			elseif self.velocity.x > 0 then
				self.renderable.flip_x = false
				set_anim_spr_animation(self.anim_controller, 'walk')
			elseif self.velocity.x == 0 then
				self.renderable.flip_x = false
				set_anim_spr_animation(self.anim_controller, 'idle')
			end

			-- Keep the player inside the screen bounds
			local player_width = 8
			if self.position.x < 0 then
				self.position.x = 0
			elseif self.position.x + player_width > 127 then
				self.position.x = 127 - player_width
			end
		end

		update_anim_spr_controller(self.anim_controller, self)
	end

	add(scene, new_player)
	return new_player
end

--
-- Create the weed highlighter
--
function make_weed_highlighter(owner, sprite)
	local highlighter = make_game_object("highlighter", 0, -8)
	highlighter.owner = owner
	attach_renderable(highlighter, sprite)

	highlighter.update = function (self)
		local my_center = 8 / 2
		local owner_center = owner.position.x + (8 / 2)	-- Hardcoded to an owner width of 8px
		local column = g_weed_generator.pixel_to_column(owner_center)
		self.position.x = g_weed_generator.column_to_pixel(column) - my_center

		local weed = g_weed_generator.weeds[column]
		if weed ~= nil and not is_weed_fully_grown(weed) then
			self.position.y = weed.position.y - weed.weed.pull_offset - weed.weed.stem_height - 8 - (8 / 2) - 2	-- Draw highlighter above the weed
		else
			self.position.y = -8	-- Offscreen
		end
	end

	add(scene, highlighter)

	return highlighter
end

--
-- Weed
--
function make_weed(name, growth_frames, stem_max_height, stem_growth_rate, stem_colour, root_max_height, root_growth_rate, root_colour, reroot_speed)
	local weed = make_game_object(name, g_weed_generator.column_to_pixel(column), g_game_config.ground_height)

	weed.weed = {
		growth_frames = growth_frames,
		stem_height = 0,
		stem_max_height = stem_max_height,
		stem_growth_rate = stem_growth_rate,
		stem_colour = stem_colour,
		root_height = 0,
		root_max_height = root_max_height,
		root_growth_rate = root_growth_rate,
		root_colour = root_colour,
		reroot_speed = reroot_speed,
		pull_offset = 0,
	}
	attach_renderable(weed, growth_frames[1])

	--
	-- Update the weed
	--
	weed.update = function (self)
		-- Re-root if pulled partially
		if self.weed.pull_offset > 0 then
			self.weed.pull_offset -= self.weed.reroot_speed
			if self.weed.pull_offset < 0 then
				self.weed.pull_offset = 0
			end
		else
			if self.weed.stem_height < self.weed.stem_max_height then
				self.weed.stem_height += self.weed.stem_growth_rate

				if self.weed.stem_height > self.weed.stem_max_height then
					self.weed.stem_height = self.weed.stem_max_height
				end
				
				-- Check whether we should show a new growth sprite
				local growth_frame_threshold = 1
				if #self.weed.growth_frames > 1 then
					growth_frame_threshold = 1 / (#self.weed.growth_frames - 1)
				end
				
				local stem_growth_pct = self.weed.stem_height / self.weed.stem_max_height
				local index = 0
				while (stem_growth_pct > 0) do
					stem_growth_pct -= growth_frame_threshold
					index += 1
				end
				self.renderable.sprite = self.weed.growth_frames[index]
			end

			if self.weed.root_height < self.weed.root_max_height then
				self.weed.root_height += self.weed.root_growth_rate
				
				if self.weed.root_height > self.weed.root_max_height then
					self.weed.root_height = self.weed.root_max_height				
				end
			end
		end
	end

	--
	-- Custom function for rendering the weed
	--
	weed.renderable.render = function(self, position)
		local weed = self.game_obj.weed

		local adjusted_y_position = position.y - weed.pull_offset;

		-- Draw the stem
		line(position.x, adjusted_y_position, position.x, adjusted_y_position - weed.stem_height, weed.stem_colour)

		-- Draw the roots
		line(position.x, adjusted_y_position + 1, position.x, adjusted_y_position + 1 + weed.root_height, weed.root_colour)

		-- Draw the flower
		local flower_position = make_vec2(position.x, adjusted_y_position) - make_vec2(8 / 2, weed.stem_height + 8 / 2)	-- Draw the center of the flower to be at the top of the stem
		self.default_render(self, flower_position)
	end

	return weed
end

--
-- Returns true if a weed is at full height
--
function is_weed_fully_grown(weed)
	if weed == nil or weed.weed == nil then
		return false
	else
		return weed.weed.root_height == weed.weed.root_height and weed.weed.stem_height == weed.weed.stem_max_height
	end
end

--
-- Attempts to pull a weed
--
function pull_weed(weed, amount, puller)
	if weed == nil or is_weed_fully_grown(weed) then
		return
	end

	weed.weed.pull_offset += amount
	
	-- Score increases a bit for the pull.
	puller.score += 1

	if (weed.position.y + weed.weed.root_height - weed.weed.pull_offset < g_game_config.ground_height) then
		g_weed_generator.kill_weed(weed)

		-- Score increases a lot for the extraction.
		puller.score += 10
		puller.weeds_pulled += 1
	end
end

-- 
-- Weed generator
--
g_weed_generator = {
	weed_width = 1,	-- Pixels wide per weed. 128 / 4 = 32 weeds per game
	weeds = {},
	time_between_weeds = 1,
	time_until_weed = 0,
	max_weed_height = 1,
	generated_weeds = 0,
	base_growth_rate = 0.1,
	weeds_per_batch = 1,
}

--
-- Initialize the weed generator
--
g_weed_generator.init = function(weed_width, max_weed_height, time_between_weeds)
	local self = g_weed_generator
	self.weeds = {}
	self.generated_weeds = 0
	self.base_growth_rate = 0.1
	self.weeds_per_batch = 1

	self.weed_width = weed_width
	self.max_weed_height = max_weed_height
	self.time_between_weeds = time_between_weeds
	self.time_until_weed = time_between_weeds

	for col = 1, self.columns() do
		self.weeds[col] = nil
	end
end

--
-- Update the weed generator
--
g_weed_generator.update = function()
	local self = g_weed_generator
	self.time_until_weed -= 1

	if self.time_until_weed == 0 then
		for i = 1, self.weeds_per_batch do
			self.generate_weed()
		end
		self.time_until_weed = self.time_between_weeds

		-- Increase the growth speed if we've generated enough weeds
		-- Increase the number of weeds generated at once if we've generated enough weeds
		if self.generated_weeds % (self.columns() * 2) == 0 then
			local column_overflow = self.weeds_per_batch - #self.get_available_columns()
			if column_overflow < 0 then
				self.weeds_per_batch += 1
				self.base_growth_rate /= 2
			else
				self.base_growth_rate += 0.05
			end
		elseif self.generated_weeds % self.columns() == 0 then
			self.base_growth_rate += 0.05
		end
	end

	-- @DEBUG summarize
	local show_debug = false
	if show_debug then
		local message = 'weeds: '
		for i = 1, self.columns() do
			if self.weeds[i] == nil then
				message = message..' . '
			else
				if is_weed_fully_grown(self.weeds[i]) then
					message = message..' # '
				else
					message = message..' x '
				end
			end
		end
		g_log.log(message)

		message = "baserate: "..self.base_growth_rate.." # batch: "..self.weeds_per_batch
		g_log.log(message)
	end
end

--
-- Gets the number of weed columns in the game
--
g_weed_generator.columns = function ()
	return flr(128 / g_weed_generator.weed_width)
end

g_weed_generator.get_available_columns = function ()
	local self = g_weed_generator
	available_cols = {}
	for col = 1, self.columns() do
		if self.weeds[col] == nil then
			add(available_cols, col)
		end
	end

	return available_cols
end

--
-- Gets the weed at a column if there is one. If not, returns nil.
g_weed_generator.get_weed = function (column) 
	return g_weed_generator.weeds[column]
end

--
-- Generates a weed in an open column
--
g_weed_generator.generate_weed = function ()
	local self = g_weed_generator

	-- Find available columns
	available_cols = self.get_available_columns()

	-- Don't generate a weed if there's no space left
	if #available_cols == 0 then
		return
	end

	-- Choose a column at random
	local index = flr(rnd(#available_cols)) + 1
	column = available_cols[index]

	-- Generate random params
	local growth_frames = {
		{32, 33, 34, 35},
		{32, 36, 37, 38},
		{32, 39, 40, 41},
	}
	local growth_frame_index = 1 + flr(rnd(#growth_frames))
	
	local stem_max_height =  self.max_weed_height
	local stem_growth_rate = self.base_growth_rate + rnd(20) / 100
	local stem_colour = 3
	
	local root_max_height = self.max_weed_height / 2
	local root_growth_rate = stem_growth_rate / 2
	local root_colour = 5

	local reroot_speed = 0.01 + flr(rnd(10)) / 100

	-- Construct the weed
	local weed = make_weed("weed-"..column, growth_frames[growth_frame_index], stem_max_height, stem_growth_rate, stem_colour, root_max_height, root_growth_rate, root_colour, reroot_speed)
	self.weeds[column] = weed
	add(scene, weed)

	self.generated_weeds += 1
end

-- 
-- Kills a weed
--
g_weed_generator.kill_weed = function (weed)
	local self = g_weed_generator;

	for col = 1, self.columns() do
		if self.weeds[col] == weed then
			self.weeds[col] = nil
		end
	end	

	del(scene, weed)
end

g_weed_generator.are_all_weeds_grown = function ()
	local self = g_weed_generator
	local are_all_grown = true

	for col = 1, self.columns() do
		if not is_weed_fully_grown(self.weeds[col]) then
			return false
		end
	end

	return true
end

--
-- Gets the worldspace x-coordinate associated with a weed column
--
g_weed_generator.column_to_pixel = function(column)
	return (column - 1) * g_weed_generator.weed_width + flr(g_weed_generator.weed_width / 2)
end

--
-- Gets the column that contains a worldspace x-coordinate
--
g_weed_generator.pixel_to_column = function(x)
	return flr(x / g_weed_generator.weed_width) + 1
end

--
-- Makes a cloud
--
function make_cloud(name, pos_x, pos_y, sprite, velocity)
	local new_cloud = make_game_object(name, pos_x, pos_y)
	new_cloud.velocity = velocity

	attach_renderable(new_cloud, sprite)
	new_cloud.renderable.draw_order = -1	-- Draw clouds behind other scene objects

	new_cloud.update = function (self)
		self.position += self.velocity

		-- @TODO Destroy when offscreen
	end

	return new_cloud
end

--
-- Cloud generator
--
g_cloud_generator = {
	time_between_clouds = 60,
	min_speed = 0.1,
	max_speed = 0.4,
	min_y = 0,
	max_y = 24,
	generated_clouds = 0
}

--
-- Initialize the cloud generator
--
g_cloud_generator.init = function(time_between_clouds)
	g_cloud_generator.time_between_clouds = time_between_clouds
	g_cloud_generator.time_until_cloud = time_between_clouds
end

g_cloud_generator.update = function()
	local self = g_cloud_generator
	self.time_until_cloud -= 1

	if self.time_until_cloud == 0 then
		add(scene, self.generate_cloud())
		self.time_until_cloud = self.time_between_clouds
	end
end

g_cloud_generator.generate_cloud = function()
	local self = g_cloud_generator

	-- @TODO Position offscreen
	-- @TODO Pick velocity

	self.generated_clouds += 1
	local name = 'cloud-'..self.generated_clouds

	local start_on_right = (flr(rnd(2)) == 0)

	local pos_x = -8
	if start_on_right then
		pos_x = 128
	end

	local pos_y = g_cloud_generator.min_y + flr(rnd(g_cloud_generator.max_y - g_cloud_generator.min_y))
	
	local sprites = { 60, 61 }
	local sprite_index = 1 + flr(rnd(#sprites))
	local sprite = sprites[sprite_index]

	local velocity = make_vec2(g_cloud_generator.min_speed + rnd(g_cloud_generator.max_speed - g_cloud_generator.min_speed), 0)
	if start_on_right then
		velocity.x *= -1
	end

	return make_cloud(name, pos_x, pos_y, sprite, velocity)
end


--
-- Renderer subsystem
--
g_renderer = {}

--
-- Main render pipeline
--
g_renderer.render = function()
	-- Collect renderables 
	local renderables = {};
	for game_obj in all(scene) do
		if (game_obj.renderable) then
			add(renderables, game_obj)
		end
	end

	-- Sort by draw-order
	quicksort_draw_order(renderables)

	-- Draw the scene
	camera_draw_start(main_camera)
	
	map(0, 0, 0, 0, 128, 128) -- draw the whole map and let the clipping region remove unnecessary bits

	for game_obj in all(renderables) do
		game_obj.renderable.render(game_obj.renderable, game_obj.position)
	end

	camera_draw_end(main_camera)
end


--
-- Sort a renderable array by draw-order
-- 
function quicksort_draw_order(list)
	quicksort_draw_order_helper(list, 1, #list)
end

--
-- Helper function for sorting renderables by draw-order
function quicksort_draw_order_helper(list, low, high)
	if (low < high) then
		local p = quicksort_draw_order_partition(list, low, high)
		quicksort_draw_order_helper(list, low, p - 1)
		quicksort_draw_order_helper(list, p + 1, high)
	end
end

--
-- Partition a renderable list by draw_order
--
function quicksort_draw_order_partition(list, low, high)
	local pivot = list[high]
	local i = low - 1
	local temp
	for j = low, high - 1 do
		if (list[j].renderable.draw_order < pivot.renderable.draw_order) then
			i += 1
			temp = list[j]
			list[j] = list[i]
			list[i] = temp
 		end
	end

	if (list[high].renderable.draw_order < list[i + 1].renderable.draw_order) then
		temp = list[high]
		list[high] = list[i + 1]
		list[i + 1] = temp
	end

	return i + 1
end

--
-- Camera
--
function make_camera(draw_x, draw_y, draw_width, draw_height, shoot_x, shoot_y)
	local t = {
 		draw_pos = make_vec2(draw_x, draw_y),
 		draw_width = draw_width,
 		draw_height = draw_height,
 		shoot_pos = make_vec2(shoot_x, shoot_y),
 	}
	return t
end

function camera_draw_start(cam)
	local draw_x = cam.draw_pos.x
	local draw_y = cam.draw_pos.y

	local cam_x = cam.shoot_pos.x - draw_x
	local cam_y = cam.shoot_pos.y - draw_y

	camera(cam_x, cam_y)
	clip(draw_x, draw_y, cam.draw_width, cam.draw_height)
end

function camera_draw_end(cam)
	camera()
	clip()
end


--
-- Animated sprite controller
--
function attach_anim_spr_controller(game_obj, frames_per_cell, animations, start_anim, start_frame_offset)
	game_obj.anim_controller = {
		current_animation = start_anim,
		current_cell = 1,
		frames_per_cell = frames_per_cell,
		current_frame = 1 + start_frame_offset,
		animations = animations,
		flip_x = false,
		flip_y = false,
	}
	return game_obj
end

function update_anim_spr_controller(controller, game_obj)
	controller.current_frame += 1
	if (controller.current_frame > controller.frames_per_cell) then
		controller.current_frame = 1

		if (controller.current_animation != nil and controller.current_cell != nil) then
			controller.current_cell += 1
			if (controller.current_cell > #controller.animations[controller.current_animation]) then
				controller.current_cell = 1
			end
		end
	end

	if (game_obj.renderable and controller.current_animation != nil and controller.current_cell != nil) then
		game_obj.renderable.sprite = controller.animations[controller.current_animation][controller.current_cell]
	elseif (game_obj.renderable) then
		game_obj.renderable.sprite = nil
	end
end

function set_anim_spr_animation(controller, animation)
	if controller.current_animation != animation then
		controller.current_frame = 0
		controller.current_cell = 1
		controller.current_animation = animation
	end
end

--
-- 2d Vector
--
local vec2_meta = {}
function vec2_meta.__add(a, b)
	return make_vec2(a.x + b.x, a.y + b.y)
end

function vec2_meta.__sub(a, b)
	return make_vec2(a.x - b.x, a.y - b.y)
end

function vec2_meta.__mul(a, b)
	if type(a) == "number" then
		return make_vec2(a * b.x, a * b.y)
	elseif type(b) == "number" then
		return make_vec2(b * a.x, b * a.y)
	else
		return make_vec2(a.x * b.x, a.y * b.y)
	end
end

function vec2_meta.__div(a, b) 
	make_vec2(a.x / b, a.y / b)
end

function vec2_meta.__eq(a, b) 
	return a.x == b.x and a.y == b.y
end

function make_vec2(x, y) 
	local table = {
		x = x,
		y = y,
	}
	setmetatable(table, vec2_meta)
	return table;
end

function vec2_magnitude(v)
	return sqrt(v.x ^ 2 + v.y ^ 2)
end

function vec2_normalized(v) 
	local mag = vec2_magnitude(v)
	return make_vec2(v.x / mag, v.y / mag)
end

function vec2_str(v)
	return "("..v.x..", "..v.y..")"
end

--
-- Log subsystem
--
g_log = {
	show_debug = true,
	log_data = {}
}

--
-- Logs a message
--
g_log.log = function(message)
	add(g_log.log_data, message)
end

--
-- Renders the log
--
g_log.render = function()
	if (g_log.show_debug) then
		color(7)
		for i = 1, #g_log.log_data do
			print(g_log.log_data[i])
		end
	end
end

--
-- Clears the log
--
g_log.clear = function()
	g_log.log_data = {}
end