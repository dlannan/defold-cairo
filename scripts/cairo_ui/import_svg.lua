------------------------------------------------------------------------------------------------------------

print(package.path)
local xml2lua = require("scripts.libs.xml2lua")
--Uses a handler that converts the XML to a Lua table
local xmlhandler = require("scripts.libs.xmlhandler.tree")

local import_svg = {}

------------------------------------------------------------------------------------------------------------

import_svg.BuildSvg = function(self, label, svgdata)

	if(type(svgdata) ~= "table") then return end
    -- Override the label if it has been provided
    if( svgdata["label"] ) then label = svgdata["label"] end

	-- Get the label and deal with it!!!!
	local xarg = svgdata["xarg"]

    if xarg ~= nil then

		if(xarg["stroke"]) 	then xarg["stroke"] = ConvertToRGB(xarg["stroke"]) end
		if(xarg["fill"]) 	then xarg["fill"] 	= ConvertToRGB(xarg["fill"]) end	
		
		if(xarg["d"])		then xarg["d"] 		= ConvertToPath(xarg["d"]) end
	end
		
	for k,v in pairs(svgdata) do
		if k ~= "xarg" then	
			if(type(v) == "table") then 
				svgdata[k] = self:BuildSvg(k, v)
			end
		else
			svgdata[k] = xarg
		end
	end
	
	return svgdata
end

------------------------------------------------------------------------------------------------------------

import_svg.RenderSvg = function(self, x, y, svgdata)

    if(type(svgdata) ~= "table") then return end
	cr.cairo_save(self.ctx)
	cr.cairo_translate(self.ctx, x, y)
		
    self:RecursiveRenderSvg(svgdata, nil)
    cr.cairo_restore(self.ctx)
end

------------------------------------------------------------------------------------------------------------

import_svg.GetStyle = function( self, style )

	local sc = nil
	local fc = nil 
	local swidth = nil 
	
	if(style) then 
		-- Example: style="font-size:12.000;fill:#ff0000;fill-rule:evenodd;"
		local props = {}
		for key, value in string.gmatch(style, "([^: ]+):([^;]+);") do props[key] = value end

		-- If fill begins with url then its a reference - disable for time being 
		local fill = props["fill"]
		if(fill) then 
			if( string.find(fill, "url") == 1 ) then 
				fc = ConvertToRGB("#ffffff") 
			else 
				fc = ConvertToRGB(props["fill"])
			end
			sc = fc
		end
		if(props["font-size"]) then swidth = tonumber(props["font-size"]) end
	end 
	return swidth, sc, fc 
end 

------------------------------------------------------------------------------------------------------------

import_svg.RecursiveRenderSvg = function(self, svgdata, label)

	if(type(svgdata) ~= "table") then return end
	-- Override the label if it has been provided
    if( svgdata["label"] ) then label = svgdata["label"] end

	-- Get the label and deal with it!!!!
	local xargs = svgdata["xarg"]

    -- TODO: Not really sure what should be done with this. Need it?
--	if(label) == "title" then
--	end
	-- TODO: TEXT ALIGNMENT - Need to support this for proper rendering
	if(label == "text") then

		local fsize 	= tonumber(xargs["font-size"])
		local x 		= tonumber(xargs["x"])
		local y 		= tonumber(xargs["y"])
		local opacity	= tonumber(xargs["opacity"])
		local a 		= 1.0
		if(opacity) then a = opacity end
		
		local sc = xargs["stroke"]
		local color = { r=sc.r, g=sc.g, b=sc.b, a=a }
		local style = xargs["style"]
		
		-- Try newer style property
		if(style) then swidth, sc, fc = self:GetStyle( style ) end
		
		local str = svgdata[1]
		if(str ~= nil) then self:RenderText( str, x, y, fsize, color ) end


	-- This is ok, but can make it better.
    elseif(label == "ellipse") then

		local swidth 	= tonumber(xargs["stroke-width"])
		local rx 		= tonumber(xargs["rx"])
		local ry 		= tonumber(xargs["ry"])
		local cx 		= tonumber(xargs["cx"])
		local cy 		= tonumber(xargs["cy"])
		local opacity	= tonumber(xargs["opacity"])

		-- Old svg stroke property
		local sc = xargs["stroke"]
		local fc = xargs["fill"]
		local style = xargs["style"]

		-- Try newer style property
		if(style) then swidth, sc, fc = self:GetStyle( style ) end
		
		cr.cairo_save (self.ctx)
		local a 		= 1.0
		if(opacity) then a = opacity end
        cr.cairo_translate(self.ctx, cx, cy)
		cr.cairo_scale(self.ctx, 1.0, ry / rx)

        cr.cairo_set_source_rgba(self.ctx, sc.r, sc.g, sc.b, a)
        cr.cairo_set_line_width(self.ctx, swidth * ry/rx);

        cr.cairo_new_path(self.ctx)
		cr.cairo_arc(self.ctx, 0.0, 0.0, rx, 0.0, 2 * math.pi)
        cr.cairo_close_path(self.ctx);
        cr.cairo_stroke_preserve(self.ctx)

        cr.cairo_set_source_rgba(self.ctx, fc.r, fc.g, fc.b, a)
        cr.cairo_fill( self.ctx )

		cr.cairo_restore(self.ctx)


	-- Circle fits well with this system
	elseif(label == "circle") then

		local sc = xargs["stroke"]
		local fc = xargs["fill"]
	
		local width 	= tonumber(xargs["stroke-width"])
		local cx 		= tonumber(xargs["cx"])
		local cy 		= tonumber(xargs["cy"])
		local r 		= tonumber(xargs["r"])
		local opacity	= tonumber(xargs["opacity"])

		local a 		= 1.0
		if(opacity ~= nil) then a = opacity end
		local style = xargs["style"]
		
		-- Try newer style property
		if(style) then swidth, sc, fc = self:GetStyle( style ) end
		
        cr.cairo_set_source_rgba(self.ctx, sc.r, sc.g, sc.b, a)
        cr.cairo_set_line_width (self.ctx, width);

		cr.cairo_arc (self.ctx, cx, cy, r, 0, 2 * math.pi)
        cr.cairo_close_path(self.ctx);

		cr.cairo_stroke_preserve (self.ctx)

        cr.cairo_set_source_rgba(self.ctx, fc.r, fc.g, fc.b, a)
        cr.cairo_fill( self.ctx )

	elseif(label == "path") then

		local sc = xargs["stroke"]
		local fc = xargs["fill"]
		local opacity	= tonumber(xargs["opacity"])

		local swidth 	= tonumber(xargs["stroke-width"])
		local style = xargs["style"]
		
		-- Try newer style property
		if(style) then swidth, sc, fc = self:GetStyle( style ) end
		
		if(xargs["d"]) then

			local a 		= 1.0
			if(opacity) then a = opacity end
			local xypoints = xargs["d"]

            cr.cairo_set_line_width(self.ctx, swidth)
            cr.cairo_set_source_rgba(self.ctx, sc.r, sc.g, sc.b, a)
            cr.cairo_new_path(self.ctx)
			cr.cairo_move_to (self.ctx, xypoints[1].x, xypoints[1].y)
			for pts = 2,#xypoints do
				cr.cairo_rel_line_to(self.ctx, xypoints[pts].x, xypoints[pts].y);
			end
			cr.cairo_close_path(self.ctx)
            cr.cairo_stroke_preserve(self.ctx)

			cr.cairo_set_source_rgba(self.ctx, fc.r, fc.g, fc.b, a)
            cr.cairo_fill( self.ctx )
		end

	
	-- Standard rect.. all good.
	elseif(label == "rect") then

		local sc = xargs["stroke"]
		local fc = xargs["fill"]
		local opacity	= tonumber(xargs["opacity"])
		
		local swidth 	= tonumber(xargs["stroke-width"])
		local width 	= tonumber(xargs["width"])
		local height 	= tonumber(xargs["height"])
		local x 		= tonumber(xargs["x"])
		local y 		= tonumber(xargs["y"])
		
		local a 		= 1.0
		if(opacity) then a = opacity end
		local style = xargs["style"]
		
		-- Try newer style property
		if(style) then swidth, sc, fc = self:GetStyle( style ) end
		
        cr.cairo_set_line_width (self.ctx, swidth)
		cr.cairo_set_source_rgba(self.ctx, sc.r, sc.g, sc.b, a)
        cr.cairo_rectangle(self.ctx, x, y, width, height)
        cr.cairo_stroke_preserve (self.ctx)

		cr.cairo_set_source_rgba(self.ctx, fc.r, fc.g, fc.b, a)
        cr.cairo_fill( self.ctx )
	end

	for k,v in pairs(svgdata) do

        if k ~= "xarg" then
			if(type(v) == "table") then 
				self:RecursiveRenderSvg(v, k)
			end
		end
	end	
end

------------------------------------------------------------------------------------------------------------

import_svg.LoadSvg = function( self, filename)

    local xmldata = LoadXml(filename, 1)

	local xml = sys.load_resource(filename)
	--Instantiates the XML parser
	local parser = xml2lua.parser(xmlhandler)
	parser:parse(xml)
	-- xml2lua.printable(xmlhandler.root)

	-- Root level should have svg label and xargs containing surface information
    local svgdata = xmldata.svg

	if(xmldata.svg) then
        -- Get the surface sizes, and so forth
		local xargs = svgdata["xarg"]
		local width = tonumber(xargs["width"])
		local height = tonumber(xargs["height"])
		local xmlns = xargs["xmlns"]

		for k,v in pairs(svgdata) do
            local temp = self:BuildSvg(k, v)
            svgdata[k] = temp
		end
	end

	return svgdata
end

------------------------------------------------------------------------------------------------------------

import_svg.AddSvg = function(self, svgdata)

    table.insert(self.svgs, svgdata)
end

------------------------------------------------------------------------------------------------------------

return import_svg

------------------------------------------------------------------------------------------------------------
