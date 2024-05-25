local S = minetest.get_translator("worldedit_commands")

local terraform = {}

mh = worldedit.manip_helpers

local radius_limit = minetest.settings:get("radius_limit")

if (radius_limit == nil) then
	radius_limit = 10
	minetest.settings:set("radius_limit",10)
end

local threshold_multiplier = minetest.settings:get("threshold_multiplier")

if (threshold_multiplier == nil) then
	threshold_multiplier = 1
	minetest.settings:set("threshold_multiplier",1)
end

local function createGaussianKernel(radius, sigma)
    local size = 2 * radius + 1
    local kernel = {}
    local sum = 0
    
    for x = -radius, radius do
        kernel[x + radius + 1] = {}
        for y = -radius, radius do
            kernel[x + radius + 1][y + radius + 1] = {}
            for z = -radius, radius do
                local exponent = -(x*x + y*y + z*z) / (2 * sigma * sigma)
                local value = math.exp(exponent) / (2 * math.pi * sigma * sigma)
                kernel[x + radius + 1][y + radius + 1][z + radius + 1] = value
                sum = sum + value
            end
        end
    end
    
    -- Normalize the kernel
    for x = 1, size do
        for y = 1, size do
            for z = 1, size do
                kernel[x][y][z] = kernel[x][y][z] / sum
            end
        end
    end
    
    return kernel
end

local kernelradius = 4
local kernel = createGaussianKernel(kernelradius, 2)

terraform.terraform = function(pos,radius,threshold,shape)
    
    local manip, area = mh.init_radius(pos, radius+kernelradius)

	local data = mh.get_empty_data(area)

	local min_radius, max_radius = radius * (radius - 1), radius * (radius + 1)
	local offset_x, offset_y, offset_z = pos.x - area.MinEdge.x, pos.y - area.MinEdge.y, pos.z - area.MinEdge.z
	local stride_z, stride_y = area.zstride, area.ystride

    local function convolute(conpos)
        local sum = 0
        for kx = -kernelradius, kernelradius do
            for ky = -kernelradius, kernelradius do
                for kz = -kernelradius, kernelradius do
                    local temppos = vector.new(conpos.x + kx, conpos.y + ky, conpos.z + kz)
                    local node = manip:get_node_at(temppos)
                    if node.name ~= "ignore" then
                        if node.name ~= "air" then
                            sum = sum + kernel[kx + kernelradius + 1][ky + kernelradius + 1][kz + kernelradius + 1]
                        end
                    end
                end
            end
        end
        return sum -- magic number
    end

	for z = -radius, radius do
		-- Offset contributed by z plus 1 to make it 1-indexed
		local new_z = (z + offset_z) * stride_z + 1
		for y = -radius, radius do
			local new_y = new_z + (y + offset_y) * stride_y
			for x = -radius, radius do
				local squared = x * x + y * y + z * z
				if (shape or squared <= max_radius) then
					-- Position is in sphere/cube
                    local manip_index = new_y + (x + offset_x)
                    if (convolute(vector.new(x + pos.x, y+pos.y, z+pos.z)) > threshold) then
                        data[manip_index] = minetest.get_content_id(manip:get_node_at(pos).name)
                    else
                        data[manip_index] = minetest.get_content_id("air")
                    end
				end
			end
		end
	end
    
	mh.finish(manip, data)
end

terraform.check_terraform = function(param)
	local found, _, radius, threshold, shape = param:find("^(%d+)%s+(%d+)%s+(%a+)$")
	if found == nil then
		return false
	end
    if (tonumber(threshold) > 1) then threshold = 1 end
    if(shape == "cube") then shape = true else shape = false end
	return true, tonumber(radius), (tonumber(threshold*threshold_multiplier)/5)+0.4, shape
end

worldedit.register_command("terraform", {
	params = "<radius> <shape> <threshold offset>",
	description = S("Terraform the blocks in <shape>(true = cube, false = sphere) at WorldEdit position 1 with radius <radius> and <threshold> [0,1], <radius> is limited to conf max radius."),
	privs = {worldedit=true},
    require_pos = 1,
    parse = terraform.check_terraform,
	func = function(name, radius, threshold,shape)
		terraform.terraform(worldedit.pos1[name], radius, threshold, shape)
	end,
})