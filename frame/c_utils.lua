--------------------------------------------------------------------------------
--
--  This file is part of the Doxyrest toolkit.
--
--  Doxyrest is distributed under the MIT license.
--  For details see accompanying license.txt file,
--  the public copy of which is also available at:
--  http://tibbo.com/downloads/archive/doxyrest/license.txt
--
--------------------------------------------------------------------------------

function getNormalizedCppString (string)
	local s = string

	s = string.gsub (s, "%s*%*", "*")
	s = string.gsub (s, "%s*&", "&")
	s = string.gsub (s, "<%s*", " <")
	s = string.gsub (s, "%s+>", ">")
	s = string.gsub (s, "%(%s*", " (")
	s = string.gsub (s, "%s+%)", ")")

	return s
end

function getLinkedTextString (text, isRef)
	if not text then
		return ""
	end

	if not isRef then
		return text.m_plainText
	end

	local s = ""

	for i = 1, #text.m_refTextArray do
		local refText = text.m_refTextArray [i]
		local text = getNormalizedCppString (refText.m_text)

		if refText.m_id ~= "" then
			text = string.gsub (text, "<", "\\<") -- escape left chevron
			s = s .. ":ref:`" .. text .. "<doxid-" .. refText.m_id .. ">`"
		else
			s = s .. text
		end
	end

	s = string.gsub (s, "\n", " ") -- callsites of getLinkedTextString don't expect newline chars

	return s
end

function getParamString (param, isRef)
	local s = ""
	local name

	if not param.m_type.m_isEmpty then
		s = s .. getLinkedTextString (param.m_type, isRef)
	end

	if param.m_declarationName ~= "" then
		name = param.m_declarationName
	else
		name = param.m_definitionName
	end

	if name ~= "" then
		if s ~= "" then
			s = s .. " "
		end

		s = s .. getNormalizedCppString (name)
	end

	if param.m_array ~= "" then
		s = s .. " " .. param.m_array
	end

	if not param.m_defaultValue.m_isEmpty then
		s = s .. " = " .. getLinkedTextString (param.m_defaultValue, isRef)
	end

	return s
end

function getParamArrayString_sl (paramArray, isRef, lbrace, rbrace)
	local s
	local count = #paramArray

	if count == 0 then
		s = lbrace .. rbrace
	else
		s = lbrace .. getParamString (paramArray [1], isRef)

		for i = 2, count do
			s = s .. ", " .. getParamString (paramArray [i], isRef)
		end

		s = s .. rbrace
	end

	return s
end

function getParamArrayString_ml (paramArray, isRef, lbrace, rbrace, indent)
	local s
	local count = #paramArray

	if count == 0 then
		s = lbrace .. rbrace
	elseif count == 1  then
		s = lbrace .. getParamString (paramArray [1], isRef) .. rbrace
	else
		s = lbrace .. "\n" .. indent .. "    "

		for i = 1, count do
			s = s .. getParamString (paramArray [i], isRef)

			if i ~= count then
				s = s .. ","
			end

			s = s .. "\n" .. indent .. "    "
		end
		s = s .. rbrace
	end

	return s
end

function getFunctionParamArrayString (paramArray, isRef, indent)
	return getParamArrayString_ml (paramArray, isRef, "(", ")", indent)
end

function getTemplateParamArrayString (paramArray, isRef)
	return getParamArrayString_sl (paramArray, isRef, "<", ">")
end

function getDefineParamArrayString (paramArray, isRef)
	return getParamArrayString_sl (paramArray, isRef, "(", ")")
end

function getItemKindString (item, itemKindString)
	local s = ""

	if item.m_modifiers ~= "" then
		s = item.m_modifiers .. " "
	end

	s = s .. itemKindString
	return s
end

function getItemNameSuffix (item)
	local s = ""

	if item.m_templateParamArray and #item.m_templateParamArray > 0 then
		s = s .. " " .. getTemplateParamArrayString (item.m_templateParamArray)
	end

	if item.m_templateSpecParamArray and #item.m_templateSpecParamArray > 0 then
		s = s .. " " .. getTemplateParamArrayString (item.m_templateSpecParamArray)
	end

	return s
end

function getItemSimpleName (item)
	return item.m_name .. getItemNameSuffix (item)
end

function getItemQualifiedName (item)
	local name = string.gsub (item.m_path, "/", g_nameDelimiter)
	return name .. getItemNameSuffix (item)
end

getItemName = getItemQualifiedName

function getItemNameForOverview (item)
	if hasItemRefTarget (item) then
		return ":ref:`" .. getItemName (item) .. "<doxid-" .. item.m_id .. ">`"
	else
		return getItemName (item)
	end
end

function getGroupName (group)
	local s
	if string.len (group.m_title) ~= 0 then
		s = group.m_title
	else
		s = group.m_name
	end

	return s
end

g_itemCidMap = {}
g_itemFileNameMap = {}

function ensureUniqueItemName (item, name, map, sep)
	local mapValue = map [name]

	if mapValue == nil then
		mapValue = {}
		mapValue.m_itemMap = {}
		mapValue.m_itemMap [item.m_id] = 1
		mapValue.m_count = 1
		map [name] = mapValue
	else
		local index = mapValue.m_itemMap [item.m_id]

		if index == nil then
			index = mapValue.m_count + 1
			mapValue.m_itemMap [item.m_id] = index
			mapValue.m_count = mapValue.m_count + 1
		end

		if index ~= 1 then
			name = name .. sep .. index

			if map [name] then
				-- solution - try some other separator on collision; but when a proper naming convention is followed, this should never happen.
				error ("name collision at: " .. name)
			end
		end
	end

	return name
end

function getItemFileName (item, suffix)
	local s

	if item.m_compoundKind then
		s = item.m_compoundKind .. "_"
	elseif item.m_memberKind then
		s = item.m_memberKind .. "_"
	else
		s = "undef_"
	end

	if item.m_compoundKind == "group" then
		s = s .. item.m_name
		-- s = string.gsub (s, '-', "_") -- groups can contain dashes, get rid of those
	else
		local path = string.gsub (item.m_path, "/operator[%s%p]+$", "/operator")
		s = s .. string.gsub (path, "/", "_")
	end

	s = ensureUniqueItemName (item, s, g_itemFileNameMap, "-")

	if not suffix then
		suffix = ".rst"
	end

	s = s .. suffix

	return s
end

function getItemCid (item)
	local s

	if item.m_compoundKind == "group" then
		s = item.m_name
	else
		s = string.gsub (item.m_path, "/operator[%s%p]+$", "/operator")
		s = string.gsub (s, "@[0-9]+/", "")
		s = string.gsub (s, "/", g_nameDelimiter)
	end

	s = string.lower (s)
	s = ensureUniqueItemName (item, s, g_itemCidMap, "-")

	return s
end

function getItemImportArray (item)
	if item.m_importArray and next (item.m_importArray) ~= nil then
		return item.m_importArray
	end

	local text = getItemInternalDocumentation (item)
	local importArray = {}
	local i = 1
	for import in string.gmatch (text, ":import:([^:]+)") do
		importArray [i] = import
		i = i + 1
	end

	return importArray
end

function getItemImportString (item)
	local importArray = getItemImportArray (item)
	if next (importArray) == nil then
		return ""
	end

	local importPrefix
	local importSuffix

	if string.match (g_language, "^c[px+]*$") then
		importPrefix = "\t#include <"
		importSuffix = ">\n"
	elseif string.match (g_language, "^ja?ncy?$") then
		importPrefix = "\timport \""
		importSuffix = "\"\n"
	else
		importPrefix = "\timport "
		importSuffix = "\n"
	end

	local s =
		".. code-block:: " .. g_language .. "\n" ..
		"\t:class: overview-code-block\n\n"

	for i = 1, #importArray do
		local import = importArray [i]
		s = s .. importPrefix .. import .. importSuffix
	end

	return s
end

function getItemRefTargetString (item)
	local s =
		".. _doxid-" .. item.m_id .. ":\n" ..
		".. _cid-" .. getItemCid (item) .. ":\n"

	if item.m_isSubGroupHead then
		for j = 1, #item.m_subGroupSlaveArray do
			slaveItem = item.m_subGroupSlaveArray [j]

			s = s ..
				".. _doxid-" .. slaveItem.m_id .. ":\n" ..
				".. _cid-" .. getItemCid (slaveItem) .. ":\n"
		end
	end

	return s
end

function hasItemRefTarget (item)
	return item.m_hasDocumentation or item.m_subGroupHead
end

function getItemArrayOverviewRefTargetString (itemArray)
	local s = ""

	for i = 1, #itemArray do
		local item = itemArray [i]
		if not hasItemRefTarget (item) then
			s = s .. getItemRefTargetString (item)
		end
	end

	return  s
end

function getEnumOverviewRefTargetString (enum)
	local s = ""

	for i = 1, #enum.m_enumValueArray do
		local enumValue = enum.m_enumValueArray [i]
		if not hasItemRefTarget (enumValue) then
			s = s .. getItemRefTargetString (enumValue)
		end
	end

	return  s
end

function getEnumArrayOverviewRefTargetString (enumArray)
	local s = ""

	for i = 1, #enumArray do
		local enum = enumArray [i]
		if isUnnamedItem (enum) then
			s = s .. getEnumOverviewRefTargetString (enum)
		end
	end

	return  s
end

function isTocTreeItem (compound, item)
	return not item.m_groupId or item.m_groupId == compound.m_id
end

function getCompoundTocTree (compound)
	local s = ".. toctree::\n\t:hidden:\n\n"

	for i = 1, #compound.m_groupArray do
		local item = compound.m_groupArray [i]
		local fileName = getItemFileName (item)
		s = s .. "\t" .. fileName .. "\n"
	end

	for i = 1, #compound.m_namespaceArray do
		local item = compound.m_namespaceArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_enumArray do
		local item = compound.m_enumArray [i]
		if isTocTreeItem (compound, item) and not isUnnamedItem (item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_structArray do
		local item = compound.m_structArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_unionArray do
		local item = compound.m_unionArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_interfaceArray do
		local item = compound.m_interfaceArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_exceptionArray do
		local item = compound.m_exceptionArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_classArray do
		local item = compound.m_classArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_singletonArray do
		local item = compound.m_singletonArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	for i = 1, #compound.m_serviceArray do
		local item = compound.m_serviceArray [i]
		if isTocTreeItem (compound, item) then
			local fileName = getItemFileName (item)
			s = s .. "\t" .. fileName .. "\n"
		end
	end

	return trimTrailingWhitespace (s)
end

function getGroupTree (group, indent)
	local s = ""

	if not indent then
		indent = ""
	end

	local name = getGroupName (group)
	name = string.gsub (name, "<", "\\<") -- escape left chevron

	s = "|\t" .. indent .. ":ref:`" .. name .. "<doxid-" ..group.m_id .. ">`\n"

	for i = 1, #group.m_groupArray do
		s = s .. getGroupTree (group.m_groupArray [i], indent .. "\t")
	end

	return s
end

function getNamespaceTree (nspace, indent)
	local s = ""

	if not indent then
		indent = ""
	end

	s = "\t" .. indent .. "namespace :ref:`" .. getItemQualifiedName (nspace) .. "<doxid-" .. nspace.m_id ..">`\n"

	for i = 1, #nspace.m_namespaceArray do
		s = s .. getNamespaceTree (nspace.m_namespaceArray [i], indent .. "    ")
	end

	return s
end

function getDoubleSectionName (title1, count1, title2, count2)
	local s

	if count1 == 0 then
		if count2 == 0 then
			s = "<Empty>" -- should not really happen
		else
			s = title2
		end
	else
		if count2 == 0 then
			s = title1
		else
			s = title1 .. " & " .. title2
		end
	end

	return s
end

function getTitle (title, underline)
	if not title or  title == "" then
		title = "<Untitled>"
	end

	return title .. "\n" .. string.rep (underline, #title)
end

function getProtectionSuffix (item)
	if item.m_protectionKind and item.m_protectionKind ~= "public" then
		return " // " .. item.m_protectionKind
	else
		return ""
	end
end

function getPropertyDeclString (item, isRef, indent)
	local s = getLinkedTextString (item.m_returnType, true)

	if item.m_modifiers ~= "" then
		s = string.gsub (s, "property", item.m_modifiers .. " property")
	end

	if g_hasNewLineAfterReturnType then
		s = s .. "\n" .. indent
	else
		s = s .. " "
	end

	if isRef then
		s = s .. ":ref:`" .. getItemName (item)  .. "<doxid-" .. item.m_id .. ">` "
	else
		s = s .. getItemName (item) ..  " "
	end

	if #item.m_paramArray > 0 then
		s = s .. getFunctionParamArrayString (item.m_paramArray, true, indent)
	end

	return s
end

function getFunctionDeclStringImpl (item, returnType, isRef, indent)
	local s = ""

	if returnType and returnType ~= "" then
		s = returnType

		if g_hasNewLineAfterReturnType then
			s = s .. "\n" .. indent
		else
			s = s .. " "
		end
	end

	if item.m_modifiers ~= "" then
		s = s .. item.m_modifiers

		if g_hasNewLineAfterReturnType then
			s = s .. "\n" .. indent
		else
			s = s .. " "
		end
	end

	if isRef then
		s = s .. ":ref:`" .. getItemName (item)  .. "<doxid-" .. item.m_id .. ">` "
	else
		s = s .. getItemName (item) ..  " "
	end

	s = s .. getFunctionParamArrayString (item.m_paramArray, true, indent)

	return s
end

function getFunctionDeclString (func, isRef, indent)
	return getFunctionDeclStringImpl (
		func,
		getLinkedTextString (func.m_returnType, true),
		isRef,
		indent
		)
end

function getVoidFunctionDeclString (func, isRef, indent)
	return getFunctionDeclStringImpl (
		func,
		nil,
		isRef,
		indent
		)
end

function getEventDeclString (event, isRef, indent)
	return getFunctionDeclStringImpl (
		event,
		"event",
		isRef,
		indent
		)
end

function getDefineDeclString (define, isRef)
	local s = "#define "

	if isRef then
		s = s .. ":ref:`" .. define.m_name  .. "<doxid-" .. define.m_id .. ">`"
	else
		s = s .. define.m_name
	end

	if #define.m_paramArray > 0 then
		-- no space between name and params!

		s = s .. getDefineParamArrayString (define.m_paramArray, true)
	end

	return s
end

function getTypedefDeclString (typedef, isRef, indent)
	local s = "typedef"

	if next (typedef.m_paramArray) == nil then
		s = s .. " " .. getLinkedTextString (typedef.m_type, true) .. " "

		if isRef then
			s = s .. ":ref:`" .. getItemName (typedef)  .. "<doxid-" .. typedef.m_id .. ">`"
		else
			s = s .. getItemName (typedef)
		end

		if typedef.m_argString ~= "" then
			s = s .. " " .. typedef.m_argString

			-- todo -- re-format argstring according to the current coding style
		end

		return s
	end

	if g_hasNewLineAfterReturnType then
		s = s .. "\n" .. indent
	else
		s = s .. " "
	end

	s = s .. getLinkedTextString (typedef.m_type, true)

	if g_hasNewLineAfterReturnType then
		s = s .. "\n" .. indent
	else
		s = s .. " "
	end

	if isRef then
		s = s .. ":ref:`" .. getItemName (typedef)  .. "<doxid-" .. typedef.m_id .. ">` "
	else
		s = s .. getItemName (typedef) ..  " "
	end

	s = s .. getFunctionParamArrayString (typedef.m_paramArray, true, indent)
	return s
end

function isMemberOfUnnamedType (item)
	local text = getItemInternalDocumentation (item)
	return string.match (text, ":unnamed:([%w/:]+)")
end

function isUnnamedItem (item)
	return item.m_name == "" or string.sub (item.m_name, 1, 1) == "@"
end

-------------------------------------------------------------------------------

-- whitespace handling

function trimLeadingWhitespace (string)
	local s = string.gsub (string, "^%s+", "")
	return s
end

function trimTrailingWhitespace (string)
	local s = string.gsub (string, "%s+$", "")
	return s
end

function trimWhitespace (string)
	local s = trimLeadingWhitespace (string)
	return trimTrailingWhitespace (s)
end

-------------------------------------------------------------------------------

-- item documentation utils

function replaceCommonSpacePrefix (source, replacement)
	local s = "\n" .. source -- add leading '\n'
	local prefix = nil
	local len = 0

	for newPrefix in string.gmatch (s, "(\n[ \t]*)[^%s]") do
		if not prefix then
			prefix = newPrefix
			len = string.len (prefix)
		else
			local newLen = string.len (newPrefix)
			if newLen < len then
				len = newLen
			end

			for i = 2, len do
				if string.byte (prefix, i) ~= string.byte (newPrefix, i) then
					len = i - 1
					break
				end
			end

			prefix = string.sub (prefix, 1, len)
		end

		if len < 2 then
			break
		end
	end

	if not prefix then
		return source
	end

	if len < 2 and replacement == "" then
		return source
	end

	s = string.gsub (s, prefix, "\n" .. replacement) -- replace common prefix
	s = string.sub (s, 2) -- remove leading '\n'

	return s
end

function concatDocBlockContents (s1, s2)
	local length1 = string.len (s1)
	local length2 = string.len (s2)

	if length1 == 0 then
		return s2
	elseif length2 == 0 then
		return s1
	end

	local last = string.sub (s1, -1, -1)
	local first = string.sub (s2, 1, 1)

	if string.match (last, "%s") or string.match (first, "%s") then
		return s1 .. s2
	else
		return s1 .. " " .. s2
	end
end

function processListDocBlock (block, context, bullet)
	local s

	local prevIndent = context.m_listItemIndent
	local prevBullet = context.m_listItemBullet

	if not prevBullet then
		context.m_listItemIndent = ""
	else
		context.m_listItemIndent = prevIndent .. "\t"
	end

	context.m_listItemBullet = bullet

	s = getDocBlockListContentsImpl (block.m_childBlockList, context)
	s = "\n\n" .. trimTrailingWhitespace (s) .. "\n\n"

	context.m_listItemIndent = prevIndent
	context.m_listItemBullet = prevBullet

	return s
end

function processDlListDocBlock (block, context)
	local prevList = context.m_dlList
	context.m_dlList = {}

	getDocBlockListContentsImpl (block.m_childBlockList, context)

	local s =
		"\n\n.. list-table::\n" ..
		"\t:widths: 20 80\n\n"

	for i = 1, #context.m_dlList do
		s = s .. "\t*\n"
		s = s .. "\t\t- " .. context.m_dlList [i].m_title .. "\n\n"
		s = s .. "\t\t- " .. context.m_dlList [i].m_description .. "\n\n"
	end

	context.m_dlList = prevList

	return s
end

function getDocBlockContents (block, context)
	local s = ""

	local listItemBullet = context.m_listItemBullet
	local listItemIndent = context.m_listItemIndent

	if block.m_blockKind == "programlisting" then
		context.m_codeBlockKind = block.m_blockKind
		local code = getDocBlockListContentsImpl (block.m_childBlockList, context)
		context.m_codeBlockKind = nil

		code = replaceCommonSpacePrefix (code, "    ")
		code = trimTrailingWhitespace (code)

		s = "\n\n::\n\n" .. code .. "\n\n"
	elseif block.m_blockKind == "preformatted" then
		context.m_codeBlockKind = block.m_blockKind
		local code = getDocBlockListContentsImpl (block.m_childBlockList, context)
		context.m_codeBlockKind = nil

		code = replaceCommonSpacePrefix (code, "    ")
		code = trimTrailingWhitespace (code)

		-- raw seems like a better approach, but need to figure something out with indents
		s = "\n\n.. code-block:: none\n\n" .. code .. "\n\n"
	elseif block.m_blockKind == "verbatim" and g_verbatimToCodeBlock then
		context.m_codeBlockKind = block.m_blockKind
		local code = getDocBlockListContentsImpl (block.m_childBlockList, context)
		context.m_codeBlockKind = nil

		code = replaceCommonSpacePrefix (code, "    ")
		code = trimTrailingWhitespace (code)

		-- probably also need to assign some div class
		s = "\n\n.. code-block:: " .. g_verbatimToCodeBlock .. "\n\n" .. code .. "\n\n"
	elseif block.m_blockKind == "itemizedlist" then
		s = processListDocBlock (block, context, "*")
	elseif block.m_blockKind == "orderedlist" then
		s = processListDocBlock (block, context, "#.")
	elseif block.m_blockKind == "variablelist" then
		s = processDlListDocBlock (block, context)
	else
		local text = block.m_text
		local childContents = getDocBlockListContentsImpl (block.m_childBlockList, context)

		if not context.m_codeBlockKind then
			if g_escapeAsterisks then
				text = string.gsub (text, "%*", "\\*")
			end

			text = trimWhitespace (text)
			text = concatDocBlockContents (text, childContents)
		else
			text = text .. childContents

			if context.m_codeBlockKind ~= "programlisting" then
				return text
			end
		end

		if block.m_blockKind == "linebreak" then
			s = "\n\n"
		elseif block.m_blockKind == "ref" then
			text = string.gsub (text, "<", "\\<") -- escape left chevron
			s = ":ref:`" .. text .. " <doxid-" .. block.m_id .. ">`"
		elseif block.m_blockKind == "computeroutput" then
			if string.find (text, "\n") then
				s = "\n\n.. code-block:: none\n\n" .. text
			else
				s = "``" .. text .. "``"
			end
		elseif block.m_blockKind == "bold" then
			s = "**" .. text .. "**"
		elseif block.m_blockKind == "emphasis" then
			s = "*" .. text .. "*"
		elseif block.m_blockKind == "heading" then
			s = ".. rubric:: " .. text .. "\n\n"
		elseif block.m_blockKind == "sp" then
			s = " "
		elseif block.m_blockKind == "varlistentry" then
			if not context.m_dlList then
				error ("unexpected <varlistentry>")
			end

			local count = #context.m_dlList
			local entry = {}
			entry.m_title = trimWhitespace (text)
			entry.m_description = ""
			context.m_dlList [count + 1] = entry
		elseif block.m_blockKind == "listitem" then
			if context.m_dlList then
				local count = #context.m_dlList
				local entry = context.m_dlList [count]
				if entry then
					entry.m_description = trimWhitespace (text)
				end
			else
				if not context.m_listItemBullet then
					error ("unexpected <listitem>")
				end

				s = context.m_listItemIndent .. context.m_listItemBullet .. " "
				local indent = string.rep (' ', string.len (s))

				text = replaceCommonSpacePrefix (text, indent)
				text = trimWhitespace (text)

				s = s .. text .. "\n\n"
			end
		elseif block.m_blockKind == "para" then
			s = trimWhitespace (text)
			if s ~= "" then
				s = s .. "\n\n"
			end
		elseif block.m_blockKind == "parametername" then
			text = trimWhitespace (text)

			if not context.m_paramSection then
				context.m_paramSection = {}
			end

			local i = #context.m_paramSection + 1

			context.m_paramSection [i] = {}
			context.m_paramSection [i].m_name = text
			context.m_paramSection [i].m_description = ""
		elseif block.m_blockKind == "parameterdescription" then
			text = trimWhitespace (text)

			if string.find (text, "\n") then
				text = "\n" .. replaceCommonSpacePrefix (text, "\t\t  ") -- add paramter table offset "- "
			end

			if context.m_paramSection then
				local count = #context.m_paramSection
				context.m_paramSection [count].m_description = text
			end
		elseif string.match (block.m_blockKind, "sect[1-4]") then
			if block.m_id and block.m_id ~= "" then
				s = ".. _doxid-" .. block.m_id .. ":\n"
			end

			if block.m_title and block.m_title ~= "" then
				s = s .. ".. rubric:: " .. block.m_title .. ":\n"
			end

			if s ~= "" then
				s = s .. "\n" .. text
			else
				s = text
			end
		elseif block.m_blockKind == "simplesect" then
			if block.m_simpleSectionKind == "return" then
				if not context.m_returnSection then
					context.m_returnSection = {}
				end

				local count = #context.m_returnSection
				context.m_returnSection [count + 1] = text
			elseif block.m_simpleSectionKind == "see" then
				if not context.m_seeSection then
					context.m_seeSection = {}
				end

				local count = #context.m_seeSection
				context.m_seeSection [count + 1] = text
			else
				s = text
			end
		else
			s = text
		end
	end

	return s
end

function getDocBlockListContentsImpl (blockList, context)
	local s = ""

	for i = 1, #blockList do
		local block = blockList [i]
		if block.m_blockKind ~= "internal" then
			local blockContents = getDocBlockContents (block, context)
			s = concatDocBlockContents (s, blockContents)
		end
	end

	return s
end

function getDocBlockListContents (blockList)
	local context = {}
	local s = getDocBlockListContentsImpl (blockList, context)

	if context.m_paramSection then
		s = s .. "\n\n.. rubric:: Parameters:\n\n"
		s = s .. ".. list-table::\n"
		s = s .. "\t:widths: 20 80\n\n"

		for i = 1, #context.m_paramSection do
			s = s .. "\t*\n"
			s = s .. "\t\t- " .. context.m_paramSection [i].m_name .. "\n\n"
			s = s .. "\t\t- " .. context.m_paramSection [i].m_description .. "\n\n"
		end
	end

	if context.m_returnSection then
		s = s .. "\n\n.. rubric:: Returns:\n\n"

		for i = 1, #context.m_returnSection do
			s = s .. context.m_returnSection [i]
		end
	end

	if context.m_seeSection then
		s = s .. "\n\n.. rubric:: See also:\n\n"

		for i = 1, #context.m_seeSection do
			s = s .. context.m_seeSection [i]
		end
	end

	s = trimTrailingWhitespace (s)
	s = string.gsub (s, "\t", "    ") -- replace tabs with spaces

	return replaceCommonSpacePrefix (s, "")
end

function getSimpleDocBlockListContents (blockList)
	local s = ""

	for i = 1, #blockList do
		local block = blockList [i]
		s = s .. block.m_text .. getSimpleDocBlockListContents (block.m_childBlockList)
	end

	return s
end

function getItemInternalDocumentation (item)
	local s = ""

	for i = 1, #item.m_detailedDescription.m_docBlockList do
		local block = item.m_detailedDescription.m_docBlockList [i]
		if block.m_blockKind == "internal" then
			s = s .. block.m_text .. getSimpleDocBlockListContents (block.m_childBlockList)
		end
	end

	return s
end

function getItemBriefDocumentation (item, detailsRefPrefix)
	local s = getDocBlockListContents (item.m_briefDescription.m_docBlockList)

	if string.len (s) == 0 then
		s = getDocBlockListContents (item.m_detailedDescription.m_docBlockList)
		if string.len (s) == 0 then
			return ""
		end

		-- generate brief description from first sentence only
		-- matching space is to handle qualified identifiers (e.g. io.File.open)

		local i = string.find (s, "%.%s", 1)
		if i then
			s = string.sub (s, 1, i)
		end

		s = trimTrailingWhitespace (s)
		s = string.gsub (s, "\t", "    ") -- replace tabs with spaces
	end

	if detailsRefPrefix then
		s = s .. " :ref:`More...<" .. detailsRefPrefix .. "doxid-" .. item.m_id .. ">`"
	end

	return s
end

function getItemDetailedDocumentation (item)
	local brief = getDocBlockListContents (item.m_briefDescription.m_docBlockList)
	local detailed = getDocBlockListContents (item.m_detailedDescription.m_docBlockList)

	if string.len (detailed) == 0 then
		return brief
	elseif string.len (brief) == 0 then
		return detailed
	else
		return brief .. "\n\n" .. detailed
	end
end

function isDocumentationEmpty (description)
	if description.m_isEmpty then
		return true
	end

	local text = getDocBlockListContents (description.m_docBlockList)
	return string.len (text) == 0
end

function prepareItemDocumentation (item, compound)
	local hasBriefDocuemtnation = not isDocumentationEmpty (item.m_briefDescription)
	local hasDetailedDocuemtnation = not isDocumentationEmpty (item.m_detailedDescription)

	item.m_hasDocumentation = hasBriefDocuemtnation or hasDetailedDocuemtnation
	if not item.m_hasDocumentation then
		return false
	end

	if hasDetailedDocuemtnation then
		local text = getItemInternalDocumentation (item)

		item.m_isSubGroupHead = string.match (text, ":subgroup:") ~= nil
		if item.m_isSubGroupHead then
			item.m_subGroupSlaveArray = {}
		end
	end

	if item.m_groupId and compound and compound.m_id ~= item.m_groupId then
		return false -- grouped items should be documented on group pages only
	end

	return true
end

function prepareItemArrayDocumentation (itemArray, compound)

	local hasDocumentation = false
	local subGroupHead = nil

	for i = 1, #itemArray do
		local item = itemArray [i]

		local result = prepareItemDocumentation (item, compound)
		if result then
			hasDocumentation = true
			if item.m_isSubGroupHead then
				subGroupHead = item
			else
				subGroupHead = nil
			end
		elseif subGroupHead then
			table.insert (subGroupHead.m_subGroupSlaveArray, item)
			item.m_subGroupHead = subGroupHead
		end
	end

	return hasDocumentation
end

function isItemInCompoundDetails (item, compound)
	if not item.m_hasDocumentation then
		return false
	end

	return not item.m_groupId or item.m_groupId == compound.m_id
end

-------------------------------------------------------------------------------

-- item filtering utils

g_protectionKindMap = {
	public    = 0,
	protected = 1,
	private   = 2,
	package   = 3,
}

g_minProtection = 0
g_maxProtection = 3

function isItemExcludedByProtectionFilter (item)

	local protectionValue = g_protectionKindMap [item.m_protectionKind]
	if protectionValue and protectionValue > g_protectionFilterValue then
		return true
	end

	return false
end

-- returns non-public item count

function sortByProtection (array)
	if next (array) == nil then
		return 0
	end

	local bucketArray  = {}
	for i = g_minProtection, g_maxProtection do
		bucketArray [i] = {}
	end

	for i = 1, #array do
		local item = array [i]
		local protectionValue = g_protectionKindMap [item.m_protectionKind]

		if not protectionValue then
			protectionValue = 0 -- assume public
		end

		table.insert (bucketArray [protectionValue], item)
	end

	local result = {}
	local k = 1

	for i = g_minProtection, g_maxProtection do
		local bucket = bucketArray [i]

		for j = 1, #bucket do
			array [k] = bucket [j]
			k = k + 1
		end
	end

	assert (k == #array + 1)

	return #array - #bucketArray [0]
end

function hasNonPublicItems (array)
	if next (array) == nil then
		return false
	end

	local lastItem = array [#array]
	local protectionValue = g_protectionKindMap [lastItem.m_protectionKind]
	return protectionValue and protectionValue > 0
end

function isItemExcludedByLocationFilter (item)

	-- exclude c++ sources unless asked explicitly with g_includeCppSources

	if item.m_location and
		not g_includeCppSources and
		string.match (g_language, "^c[px+]*$") and
		string.match (item.m_location.m_file, "%.c[px+]*$")	then

		return true
	end

	return false
end

function filterItemArray (itemArray)
	if next (itemArray) == nil then
		return
	end

	for i = #itemArray, 1, -1 do
		local item = itemArray [i]
		local isExcluded =
			isItemExcludedByProtectionFilter (item) or
			isItemExcludedByLocationFilter (item)

		if isExcluded then
			table.remove (itemArray, i)
		end
	end
end

function filterEnumArray (enumArray)
	if next (enumArray) == nil then
		return
	end

	for i = #enumArray, 1, -1 do
		local enum = enumArray [i]
		local isExcluded =
			isItemExcludedByProtectionFilter (enum) or
			isItemExcludedByLocationFilter (enum) or
			isUnnamedItem (enum) and #enum.m_enumValueArray == 0

		if isExcluded then
			table.remove (enumArray, i)
		end
	end
end

function filterNamespaceArray (namespaceArray)
	if next (namespaceArray) == nil then
		return
	end

	for i = #namespaceArray, 1, -1 do
		local item = namespaceArray [i]
		local isExcluded =
			isUnnamedItem (item) or
			isItemExcludedByLocationFilter (item)

		if isExcluded then
			table.remove (namespaceArray, i)
		end
	end
end

function filterConstructorArray (constructorArray)
	filterItemArray (constructorArray)

	if #constructorArray == 1 then
		local item = constructorArray [1]
		local isExcluded =
			isItemExcludedByProtectionFilter (item) or
			not g_includeDefaultConstructors and #item.m_paramArray == 0

		if isExcluded then
			table.remove (constructorArray, 1)
		end
	end
end

function filterDefineArray (defineArray)
	if next (defineArray) == nil then
		return
	end

	for i = #defineArray, 1, -1 do
		local item = defineArray [i]

		local isExcluded =
			isItemExcludedByLocationFilter (item) or
			g_excludeEmptyDefines and item.m_initializer.m_isEmpty or
			g_excludeDefinePattern and string.match (item.m_name, g_excludeDefinePattern)

		if isExcluded then
			table.remove (defineArray, i)
		end
	end
end

function filterTypedefArray (typedefArray)
	if next (typedefArray) == nil then
		return
	end

	for i = #typedefArray, 1, -1 do
		local item = typedefArray [i]
		local isExcluded =
			isItemExcludedByProtectionFilter (item) or
			isItemExcludedByLocationFilter (item)

		if not isExcluded and not g_includePrimitiveTypedefs then
			local typeKind, name = string.match (
				item.m_type.m_plainText,
				"(%a+)%s+(%w[%w_]*)"
				)

			if name == item.m_name then
				isExcluded =
					item.m_briefDescription.m_isEmpty and
					item.m_detailedDescription.m_isEmpty
			end
		end

		if isExcluded then
			table.remove (typedefArray, i)
		end
	end
end

function concatenateTables (t1, t2)
	local j = #t1 + 1
	for i = 1, #t2 do
		t1 [j] = t2 [i]
		j = j + 1
	end
end

-------------------------------------------------------------------------------

-- base compound is an artificial compound holding all inherited members

function addToBaseCompound (baseCompound, baseTypeArray)
	for i = 1, #baseTypeArray do
		local baseType = baseTypeArray [i]

		-- prevent adding the same base type multiple times

		if not baseCompound.m_baseTypeMap [baseType] and
			baseType.m_compoundKind ~= "<undefined>" then

			baseCompound.m_baseTypeMap [baseType] = true
			prepareCompound (baseType)

			if next (baseType.m_baseTypeArray) ~= nil then
				addToBaseCompound (baseCompound, baseType.m_baseTypeArray)
			end

			concatenateTables (baseCompound.m_typedefArray, baseType.m_typedefArray)
			concatenateTables (baseCompound.m_enumArray, baseType.m_enumArray)
			concatenateTables (baseCompound.m_structArray, baseType.m_structArray)
			concatenateTables (baseCompound.m_unionArray, baseType.m_unionArray)
			concatenateTables (baseCompound.m_interfaceArray, baseType.m_interfaceArray)
			concatenateTables (baseCompound.m_exceptionArray, baseType.m_exceptionArray)
			concatenateTables (baseCompound.m_classArray, baseType.m_classArray)
			concatenateTables (baseCompound.m_singletonArray, baseType.m_singletonArray)
			concatenateTables (baseCompound.m_serviceArray, baseType.m_serviceArray)
			concatenateTables (baseCompound.m_variableArray, baseType.m_variableArray)
			concatenateTables (baseCompound.m_propertyArray, baseType.m_propertyArray)
			concatenateTables (baseCompound.m_eventArray, baseType.m_eventArray)
			concatenateTables (baseCompound.m_functionArray, baseType.m_functionArray)
			concatenateTables (baseCompound.m_aliasArray, baseType.m_aliasArray)
		end
	end
end

function createBaseCompound (compound)
	local baseCompound = {}

	baseCompound.m_compoundKind = "base-compound"
	baseCompound.m_baseTypeMap = {}
	baseCompound.m_namespaceArray = {}
	baseCompound.m_typedefArray = {}
	baseCompound.m_enumArray = {}
	baseCompound.m_structArray = {}
	baseCompound.m_unionArray = {}
	baseCompound.m_interfaceArray = {}
	baseCompound.m_exceptionArray = {}
	baseCompound.m_classArray = {}
	baseCompound.m_singletonArray = {}
	baseCompound.m_serviceArray = {}
	baseCompound.m_variableArray = {}
	baseCompound.m_propertyArray = {}
	baseCompound.m_eventArray = {}
	baseCompound.m_constructorArray = {}
	baseCompound.m_functionArray = {}
	baseCompound.m_aliasArray = {}
	baseCompound.m_defineArray = {}

	compound.m_baseCompound = baseCompound

	addToBaseCompound (baseCompound, compound.m_baseTypeArray)

	sortByProtection (baseCompound.m_typedefArray)
	sortByProtection (baseCompound.m_enumArray)
	sortByProtection (baseCompound.m_structArray)
	sortByProtection (baseCompound.m_unionArray)
	sortByProtection (baseCompound.m_interfaceArray)
	sortByProtection (baseCompound.m_exceptionArray)
	sortByProtection (baseCompound.m_classArray)
	sortByProtection (baseCompound.m_singletonArray)
	sortByProtection (baseCompound.m_serviceArray)
	sortByProtection (baseCompound.m_variableArray)
	sortByProtection (baseCompound.m_propertyArray)
	sortByProtection (baseCompound.m_eventArray)
	sortByProtection (baseCompound.m_functionArray)
	sortByProtection (baseCompound.m_aliasArray)
end

-------------------------------------------------------------------------------

-- compound & enum prep

function cmpIds (i1, i2)
	return i1.m_id < i2.m_id
end

function cmpNames (i1, i2)
	return i1.m_name < i2.m_name
end

function cmpTitles (i1, i2)
	return i1.m_title < i2.m_title
end

function prepareCompound (compound)
	if compound.m_stats then
		return compound.m_stats
	end

	local stats = {}

	-- scan for documentation and create subgroups

	stats.m_hasUnnamedEnums = false
	stats.m_hasDocumentedUnnamedEnumValues = false

	for i = 1, #compound.m_enumArray do
		local item = compound.m_enumArray [i]

		if isUnnamedItem (item) then
			stats.m_hasUnnamedEnums = true

			if prepareItemArrayDocumentation (item.m_enumValueArray, compound) then
				stats.m_hasDocumentedUnnamedEnumValues = true
			end
		end
	end

	stats.m_hasDocumentedTypedefs = prepareItemArrayDocumentation (compound.m_typedefArray, compound)
	stats.m_hasDocumentedVariables = prepareItemArrayDocumentation (compound.m_variableArray, compound)
	stats.m_hasDocumentedProperties = prepareItemArrayDocumentation (compound.m_propertyArray, compound)
	stats.m_hasDocumentedEvents = prepareItemArrayDocumentation (compound.m_eventArray, compound)
	stats.m_hasDocumentedFunctions = prepareItemArrayDocumentation (compound.m_functionArray, compound)
	stats.m_hasDocumentedAliases = prepareItemArrayDocumentation (compound.m_aliasArray, compound)
	stats.m_hasDocumentedDefines = prepareItemArrayDocumentation (compound.m_defineArray, compound)

	stats.m_hasDocumentedConstruction =
		prepareItemArrayDocumentation (compound.m_constructorArray, compound) or
		g_includeDestructors and compound.m_destructor and prepareItemDocumentation (compound.m_destructor, compound)

	stats.m_hasDocumentedItems =
		stats.m_hasDocumentedUnnamedEnumValues or
		stats.m_hasDocumentedTypedefs or
		stats.m_hasDocumentedVariables or
		stats.m_hasDocumentedProperties or
		stats.m_hasDocumentedEvents or
		stats.m_hasDocumentedConstruction or
		stats.m_hasDocumentedFunctions or
		stats.m_hasDocumentedAliases or
		stats.m_hasDocumentedDefines

	stats.m_hasBriefDocumentation = not isDocumentationEmpty (compound.m_briefDescription)
	stats.m_hasDetailedDocumentation = not isDocumentationEmpty (compound.m_detailedDescription)

	-- filter invisible items out

	filterNamespaceArray (compound.m_namespaceArray)
	filterTypedefArray (compound.m_typedefArray)
	filterEnumArray (compound.m_enumArray)
	filterItemArray (compound.m_structArray)
	filterItemArray (compound.m_unionArray)
	filterItemArray (compound.m_interfaceArray)
	filterItemArray (compound.m_exceptionArray)
	filterItemArray (compound.m_classArray)
	filterItemArray (compound.m_singletonArray)
	filterItemArray (compound.m_serviceArray)
	filterItemArray (compound.m_variableArray)
	filterItemArray (compound.m_propertyArray)
	filterItemArray (compound.m_eventArray)
	filterConstructorArray (compound.m_constructorArray)
	filterItemArray (compound.m_functionArray)
	filterItemArray (compound.m_aliasArray)
	filterDefineArray (compound.m_defineArray)

	stats.m_hasItems =
		#compound.m_namespaceArray ~= 0 or
		#compound.m_typedefArray ~= 0 or
		#compound.m_enumArray ~= 0 or
		#compound.m_structArray ~= 0 or
		#compound.m_unionArray ~= 0 or
		#compound.m_interfaceArray ~= 0 or
		#compound.m_exceptionArray ~= 0 or
		#compound.m_classArray ~= 0 or
		#compound.m_singletonArray ~= 0 or
		#compound.m_serviceArray ~= 0 or
		#compound.m_variableArray ~= 0 or
		#compound.m_propertyArray ~= 0 or
		#compound.m_eventArray ~= 0 or
		#compound.m_constructorArray ~= 0 or
		#compound.m_functionArray ~= 0 or
		#compound.m_aliasArray ~= 0 or
		#compound.m_defineArray ~= 0

	-- sort items -- only the ones producing separate pages;
	-- also, defines, which always go to the global namespace

	table.sort (compound.m_groupArray, cmpIds)
	table.sort (compound.m_namespaceArray, cmpNames)
	table.sort (compound.m_enumArray, cmpNames)
	table.sort (compound.m_structArray, cmpNames)
	table.sort (compound.m_unionArray, cmpNames)
	table.sort (compound.m_interfaceArray, cmpNames)
	table.sort (compound.m_exceptionArray, cmpNames)
	table.sort (compound.m_classArray, cmpNames)
	table.sort (compound.m_serviceArray, cmpNames)
	table.sort (compound.m_defineArray, cmpNames)

	-- stable sort by protection (public first)

	sortByProtection (compound.m_typedefArray)
	sortByProtection (compound.m_enumArray)
	sortByProtection (compound.m_structArray)
	sortByProtection (compound.m_unionArray)
	sortByProtection (compound.m_interfaceArray)
	sortByProtection (compound.m_exceptionArray)
	sortByProtection (compound.m_classArray)
	sortByProtection (compound.m_singletonArray)
	sortByProtection (compound.m_serviceArray)
	sortByProtection (compound.m_variableArray)
	sortByProtection (compound.m_propertyArray)
	sortByProtection (compound.m_eventArray)
	sortByProtection (compound.m_constructorArray)
	sortByProtection (compound.m_functionArray)
	sortByProtection (compound.m_aliasArray)

	compound.m_stats = stats

	if compound.m_baseTypeArray and next (compound.m_baseTypeArray) ~= nil then
		createBaseCompound (compound)
	end

	return stats
end

function prepareEnum (enum)
	local stats = {}

	stats.m_hasDocumentedEnumValues = prepareItemArrayDocumentation (enum.m_enumValueArray)
	stats.m_hasBriefDocumentation = not isDocumentationEmpty (enum.m_briefDescription)
	stats.m_hasDetailedDocumentation = not isDocumentationEmpty (enum.m_detailedDescription)

	return stats
end


-------------------------------------------------------------------------------
