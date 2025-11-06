pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function _init()
-- runs once at the start
	local m=10
	local n=20

	local probs={
		{tile=-1,p=0.01}, -- wumpus
		{tile=-2,p=0.20}, -- pit
		{tile=1,p=0.05} -- gold
	}
	
	local cumulative=make_cumulative(probs)

	world=make_world(m,n,cumulative)

end

function _update()
-- runs 30 times per second
end

function _draw()
-- runs at 30fps
end


function make_world(m, n, probs)
-- makes a new world

	local world={}
	
	for i=1,m do
		world[i]={}
		for j=1,n do
		
			world[i][j]=make_tile(probs)
			
		end
	end
	
	world[1][1]=0
	
	return world

end

function make_tile(probs)
-- defines what to put in a tile

	local number=rnd()
	
	for _,entry in ipairs(probs) do
		if number<=entry.cum_prob then
			return entry.tile
		end
	end
		
	return 0 -- if no tile was chosen then its a safe tile

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

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
