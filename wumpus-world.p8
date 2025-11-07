pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function _init()
-- runs once at the start
	local m=10
	local n=20

	local reachable={
		{tile=1,p=0.05}, -- gold
		{tile=-1,p=0.01} -- wumpus
	}
	local other={
		{tile=-2,p=0.02} -- pit
	}
	
	world=make_world(m,n,reachable,other)

end

function _update()
-- runs 30 times per second
end

function _draw()
-- runs at 30fps

	cls()
	for i=1,#world do
		for j=1,#world[i] do
			local x = (j-1)*6
			local y = (i-1)*6
			local t = world[i][j].tile
			if t == -1 then
				print("w",x,y,8)
			elseif t == -2 then
				print("p",x,y,2)
			elseif t == 1 then
				print("g",x,y,10)
			elseif world[i][j].stench then
				print("s",x,y,7)
			elseif world[i][j].breeze then
				print("b",x,y,7)
			elseif world[i][j].glitter then
				print("*",x,y,11)
			else
				print(".",x,y,5)
			end
		end
	end

end


function make_world(m, n, reachable, other)
-- makes a new world

	local world=make_empty_world(m,n) -- first we make an empty world

	local reachables=place_things(world,reachable)	-- then we place the things the player must be able to reach
	
	world[1][1].tile=0
	world[1][1].visible=true
	local safe_cells={}
	add(safe_cells,{i=1,j=1})
	
	for _,r in ipairs(reachables) do -- now we carve out paths of safe tiles from each reachable to the safe tiles we know
		best=find_nearest_safe_cell(safe_cells,r.i,r.j)
		new_safe_cells=make_safe_path(world,r.i,r.j,best.i,best.j)
		foreach(new_safe_cells, function(cell)
			add(safe_cells, cell)
		end)
	end
	
	place_things(world,other) -- now we finally place all the stuff that doesnt need to be reachable

	world[1][1].tile=0 -- finally make the (1,1) tile safe again just in case
	
	for i=1,m do -- now we flag the tiles with whatever they need (stench, breeze, etc)
		for j=1,n do
			flag_adjacent_tiles(i,j,world)
		end
	end
	
	return world
	
end

function make_empty_world(m, n)
-- makes an empty map
	
	local world={}
	
	for i=1,m do
		world[i]={}
		for j=1,n do
			world[i][j]={
				tile=nil,
				visible=false,
				glitter=false,
				stench=false,
				breeze=false,
				collected_gold=false,
				dead_wumpus=false
			}
		end
	end
	
	return world
	
end

function place_things(world, things)
	-- places things in the world
	
	local m=#world
	local n=#world[1]
	
	local placed_things={}
	
	cumulative=make_cumulative(things)	
	
	for i=1,m do
		for j=1,n do
			if world[i][j].tile==nil then
				tile=make_tile(cumulative)
				if tile~=nil then
					add(placed_things,{i=i,j=j})
					world[i][j].tile=tile
				end
			end
		end
	end
	
	return placed_things
	
end

function find_nearest_safe_cell(safe_cells, i, j)
-- finds the safe cell nearest to (i, j)

	local best=safe_cells[1]

	for _,cell in ipairs(safe_cells) do
		if ((abs(cell.i-i)+abs(cell.j-j)) < (abs(best.i-i)+abs(best.j-j))) then
			best=cell
		end
	end
	
	return best

end

function make_safe_path(world, s_i, s_j, d_i, d_j)
-- builds a path of safe tiles from (s_i, s_j) to (d_i, d_j)
-- imma be honest this one's all chatgpt ive got no idea what happens here

	local i, j = s_i, s_j
	local steps = 0
	local max_steps = (#world + #world[1]) * 4
	local new_safe = {}

	while (i ~= d_i or j ~= d_j) and steps < max_steps do
		local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
		
		-- bias toward target but allow randomness
		if rnd() < 0.6 then
			if i < d_i then dirs[1] = {1,0} end
			if i > d_i then dirs[2] = {-1,0} end
			if j < d_j then dirs[3] = {0,1} end
			if j > d_j then dirs[4] = {0,-1} end
		end

		-- pick random direction
		local d = dirs[flr(rnd(4))+1]
		local ni, nj = i + d[1], j + d[2]
		
		if world[ni] and world[ni][nj] then
			i, j = ni, nj
			-- only carve safe path if it's not start/end and not something special
			local t = world[i][j].tile
			if not (i == s_i and j == s_j) and not (i == d_i and j == d_j) then
				if t == nil or t == 0 then
					world[i][j].tile = 0
					add(new_safe, {i=i,j=j})
				end
			end
		end

		steps += 1
	end

	return new_safe
	
end

function make_tile(probs)
-- defines what to put in a tile

	local number=rnd()
	
	for _,entry in ipairs(probs) do
		if number<=entry.cum_prob then
			return entry.tile
		end
	end
		
	return nil -- if no tile type was chosen then we skip it

end

function make_cumulative(probs)
-- builds the cumulative probability vector

	local cumulative={}
	local sum=0
	
	for i,entry in ipairs(probs) do
		sum+=entry.p
		add(cumulative,{tile=entry.tile,cum_prob=sum})
	end
	
	return cumulative
	
end

function flag_adjacent_tiles(i, j, world)
-- adds the flags for tiles adjacent to wumpus, pit, gold

	local tile=world[i][j].tile

	for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
		
		local new_i=i+delta[1]
		local new_j=j+delta[2]
		
		if world[new_i] and world[new_i][new_j] then -- checks the tile exists
			
			if tile==1 then
				world[new_i][new_j].glitter=true
			elseif tile==-1 then
				world[new_i][new_j].stench=true
			elseif tile==-2 then
				world[new_i][new_j].breeze=true
			end
				
		end
		
	end

end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
