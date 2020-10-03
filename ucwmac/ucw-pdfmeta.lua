-- A library for writing PDF metadata

luatexbase.provides_module {
	name	= 'pdfmeta',
	version	= '0.0',
	author	= 'Martin Mareš',
}

pdfmeta = { }

-- Debugging function for dumping a table

local function do_dump_table(t, key, depth)
	local tmp = string.rep("  ", depth)
	if key then
		tmp = tmp .. key .. ": "
	end
	if type(t) == "table" then
		texio.write(tmp .. "{\n")
		for k, v in pairs(t) do
			do_dump_table(v, k, depth+1)
		end
		tmp = string.rep("  ", depth) .. "}"
	elseif type(t) == "number" then
		tmp = tmp .. tostring(t)
	elseif type(t) == "string" then
		tmp = tmp .. string.format("%q", t)
	else
		tmp = tmp .. "???"
	end
	texio.write(tmp .. "\n")
end

local function dump_table(t)
	do_dump_table(t, nil, 0)
end

-- PDF metadata can be encoded either in an ancient PDFEncoding, which covers
-- only a small subset of Unicode characters, or in UTF-16-BE. We use the latter
-- for anything outside basic ASCII. It is tempting to use "lualibs-unicode"
-- for the conversion, but alas, it is too broken.

local function pdf_string(s)
	local u16 = {}
	local str = {}
	local strok = true
	table.insert(u16, "<feff")
	for x in string.utfvalues(s) do
		if x >= 0x20 and x < 0x7f and x ~= 0x28 and x ~= 0x29 and x ~= 0x5c then
			if x == 0x28 or x == 0x29 or x == 0x5c then
				table.insert(str, "\\" .. string.char(x))
			else
				table.insert(str, string.char(x))
			end
		else
			strok = false
		end
		if x < 0x10000 then
			table.insert(u16, string.format("%04x", x))
		else
			local y = x - 0x10000
			local h = y/1024 + 0xd800
			local l = y%1024 + 0xdc00
			table.insert(u16, string.format("%04x%04x", h, l))
		end
	end

	if strok then
		return "(" .. table.concat(str) .. ")"
	else
		table.insert(u16, ">")
		return table.concat(u16)
	end
end

local function pdf_encode_dict_body(d)
	local t = {}
	for k, v in pairs(d) do
		table.insert(t, "/" .. k .. " " .. v)
	end
	return table.concat(t, "\n")
end

local function pdf_encode_dict(d)
	return '<< ' .. pdf_encode_dict_body(d) .. ' >>'
end

-- Metadata dictionary

pdfmeta.info = { }
pdfmeta.catalog = { }

function pdfmeta.set_info(key, val)
	pdfmeta.info[key] = pdf_string(val)
end

local function write_metas()
	pdfmeta.make_outline()
	pdf.setinfo(pdf_encode_dict_body(pdfmeta.info))
	pdf.setcatalog(pdf_encode_dict_body(pdfmeta.catalog))
end

luatexbase.add_to_callback('finish_pdffile', write_metas, 'Write all PDF metadata')

-- Document outline

pdfmeta.outline = { children = {} }
pdfmeta.outline_stack = { pdfmeta.outline }

function pdfmeta.add_outline(key, dest, text)
	local stk = pdfmeta.outline_stack
	local level = 1
	local p, r

	for k in string.gmatch(key, '%.*(%d+)') do
		level = level+1
	end
	while #stk >= level do
		table.remove(stk)
	end
	while #stk < level do
		p = stk[#stk]
		r = { children = {} }
		table.insert(p.children, r)
		table.insert(stk, r)
	end
	r.dest = dest
	text = string.gsub(text, '~', unicode.utf8.char(160))
	text = string.gsub(text, '%-%-%-', unicode.utf8.char(8212))
	text = string.gsub(text, '%-%-', unicode.utf8.char(8211))
	r.text = text;
end

local function reserve_objects(r)
	r.obj = pdf.reserveobj()
	r.num_descendants = 0
	for i, child in pairs(r.children) do
		reserve_objects(child)
		r.num_descendants = r.num_descendants + child.num_descendants + 1
	end
end

local function outline_ref(r)
	if r then
		return r.obj .. ' 0 R'
	else
		tex.error('Asked to format null reference')
		return 'nil'
	end
end

local function gen_outline(r, parent)
	d = {}
	r.dict = d

	if not parent then
		d.Type = '/Outlines'
		d.Count = r.num_descendants
	else
		d.Parent = outline_ref(parent)
		d.Count = r.num_descendants
	end

	if r.text then
		d.Title = pdf_string(r.text)
		d.A = '<< /D (' .. r.dest .. ') /S /GoTo >>'
	end

	if r.children[1] then
		d.First = outline_ref(r.children[1])
		d.Last = outline_ref(r.children[#r.children])
		for i, child in pairs(r.children) do
			gen_outline(child, r)
			if i>1 then
				child.dict.Prev = outline_ref(r.children[i-1])
			end
			if i<#r.children then
				child.dict.Next = outline_ref(r.children[i+1])
			end
		end
	end
end

local function write_outline(r)
	pdf.obj {
		type = 'raw',
		immediate = true,
		objnum = r.obj,
		string = pdf_encode_dict(r.dict),
	}
	for i, child in pairs(r.children) do
		write_outline(child)
	end
end

function pdfmeta.make_outline()
	local o = pdfmeta.outline
	reserve_objects(o)
	gen_outline(o, nil)
	-- dump_table(o)
	write_outline(o)
	pdfmeta.catalog.Outlines = outline_ref(o)
end
