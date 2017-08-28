scene = {}
player = {}
main_camera = {}
g_game_config = {
	ground_height = 64,	-- Height of the first ground pixel
}

function _init()
	main_camera = make_camera(0, 0, 128, 128, 0, 0)

	-- Player
	local player_height = 8
	local player_start_x = 128 / 2 -- Middle of the screen
	local player_start_y = g_game_config.ground_height - player_height -- 1px above the ground
	player = make_game_object("player", player_start_x, player_start_y)
	player.speed = 2
	attach_renderable(player, 1)
	add(scene, player)

	-- Weeds
	g_weed_generator.init(8, 60) 
	g_weed_generator.generate_weed()
end

function _update()
	-- Process input
	player_movement = make_vec2(0, 0)
	if btn(0) then
		player_movement.x -= player.speed
	end

	if btn(1) then
		player_movement.x += player.speed
	end

	if btn(4) then
		-- @TODO Weed
	end

	if btn(5) then
		-- @TODO Activate Powerup
	end

	-- Process player movement changes
	player.position += player_movement

	-- Keep the player inside the screen bounds
	local player_width = 8
	if player.position.x < 0 then
		player.position.x = 0
	elseif player.position.x + player_width > 127 then
		player.position.x = 127 - player_width
	end

	-- Update weed generator
	g_weed_generator.update()

	-- Update game objects
	for game_obj in all(scene) do
		if (game_obj.update) then
			game_obj.update(game_obj)
		end
	end

	g_log.log("CPU: "..stat(1))
end

function _draw()
	cls()

	g_renderer.render()
end

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
-- Weed
--
function make_weed(column, sprite, stem_max_height, stem_growth_rate, stem_colour, root_max_height, root_growth_rate, root_colour)
	local weed = make_game_object("weed_"..column, g_weed_generator.weed_column_to_pixel(column), g_game_config.ground_height)

	weed.weed = {
		stem_height = 0,
		stem_max_height = stem_max_height,
		stem_growth_rate = stem_growth_rate,
		stem_colour = stem_colour,
		root_height = 0,
		root_max_height = root_max_height,
		root_growth_rate = root_growth_rate,
		root_colour = root_colour,
	}
	attach_renderable(weed, sprite)

	--
	-- Update the weed
	--
	weed.update = function (self)
		if self.weed.stem_height < self.weed.stem_max_height then
			self.weed.stem_height += self.weed.stem_growth_rate

			if self.weed.stem_height > self.weed.stem_max_height then
				self.weed.stem_height = self.weed.stem_max_height				
			end
		end

		if self.weed.root_height < self.weed.root_max_height then
			self.weed.root_height += self.weed.root_growth_rate
			
			if self.weed.root_height > self.weed.root_max_height then
				self.weed.root_height = self.weed.root_max_height				
			end
		end
	end

	--
	-- Custom function for rendering the weed
	--
	weed.renderable.render = function(self, position)
		local weed = self.game_obj.weed

		-- Draw the stem
		line(position.x, position.y, position.x, position.y - weed.stem_height, weed.stem_colour)

		-- Draw the roots
		line(position.x, position.y + 1, position.x, position.y + 1 + weed.root_height, weed.root_colour)

		-- Draw the flower
		local flower_position = position - make_vec2(8 / 2, weed.stem_height + 8 / 2)	-- Draw the center of the flower to be at the top of the stem
		self.default_render(self, flower_position)
	end

	return weed
end

-- 
-- Weed generator
g_weed_generator = {
	weed_width = 1,	-- Pixels wide per weed. 128 / 4 = 32 weeds per game
	weeds = {},
	time_between_weeds = 1,
	time_until_weed = 0,
}

g_weed_generator.init = function(weed_width, time_between_weeds)
	local self = g_weed_generator

	self.weed_width = weed_width
	self.time_between_weeds = time_between_weeds
	self.time_until_weed = time_between_weeds

	for col = 1, self.columns() do
		self.weeds[col] = nil
	end
end

g_weed_generator.update = function()
	local self = g_weed_generator
	self.time_until_weed -= 1

	if self.time_until_weed == 0 then
		self.generate_weed()
		self.time_until_weed = self.time_between_weeds
	end
end

g_weed_generator.columns = function ()
	return flr(128 / g_weed_generator.weed_width)
end

g_weed_generator.generate_weed = function ()
	local self = g_weed_generator

	-- Find available columns
	available_cols = {}
	for col = 1, self.columns() do
		if self.weeds[col] == nil then
			add(available_cols, col)
		end
	end

	-- Don't generate a weed if there's no space left
	if #available_cols == 0 then
		return
	end

	-- Choose a column at random
	local column = flr(rnd(#available_cols)) + 1
	column = available_cols[column]

	-- Generate random params
	local sprite = 32
	
	local stem_max_height = flr(rnd(32)) + 20
	local stem_growth_rate = 0.1 + rnd(90) / 100
	local stem_colour = 3
	
	local root_max_height = flr(rnd(32)) + 20
	local root_growth_rate = 0.1 + rnd(90) / 100
	local root_colour = 5

	-- Construct the weed
	local weed = make_weed(column, sprite, stem_max_height, stem_growth_rate, stem_colour, root_max_height, root_growth_rate, root_colour)
	self.weeds[column] = weed
	add(scene, weed)
end

--
-- Gets the worldspace x-coordinate associated with a weed column
--
g_weed_generator.weed_column_to_pixel = function(column)
	return column * g_weed_generator.weed_width + flr(g_weed_generator.weed_width / 2)
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

	-- @TODO Depth-sort?

	-- Draw the scene
	camera_draw_start(main_camera)
	
	map(0, 0, 0, 0, 128, 128) -- draw the whole map and let the clipping region remove unnecessary bits

	for game_obj in all(renderables) do
		game_obj.renderable.render(game_obj.renderable, game_obj.position)
	end

	camera_draw_end(main_camera)

	-- Draw debug log
	g_log.render()
	g_log.clear()
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