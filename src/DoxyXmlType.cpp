//..............................................................................
//
//  This file is part of the Doxyrest toolkit.
//
//  Doxyrest is distributed under the MIT license.
//  For details see accompanying license.txt file,
//  the public copy of which is also available at:
//  http://tibbo.com/downloads/archive/doxyrest/license.txt
//
//..............................................................................

#include "pch.h"
#include "DoxyXmlType.h"
#include "DoxyXmlParser.h"

//..............................................................................

bool
DoxygenIndexType::create (
	DoxyXmlParser* parser,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;

	Module* module = m_parser->getModule ();

	while (*attributes)
	{
		IndexAttrKind attrKind = IndexAttrKindMap::findValue (attributes [0], IndexAttrKind_Undefined);
		switch (attrKind)
		{
		case IndexAttrKind_Version:
			module->m_version = attributes [1];
			break;
		}

		attributes += 2;
	}

	return true;
}

bool
DoxygenIndexType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	IndexElemKind elemKind = IndexElemKindMap::findValue (name, IndexElemKind_Undefined);
	switch (elemKind)
	{
	case IndexElemKind_Compound:
		onCompound (name, attributes);
		break;
	}

	return true;
}

bool
DoxygenIndexType::onCompound (
	const char* name,
	const char** attributes
	)
{
	sl::String refId;
	CompoundKind compoundKind;

	while (*attributes)
	{
		CompoundAttrKind attrKind = CompoundAttrKindMap::findValue (attributes [0], CompoundAttrKind_Undefined);
		switch (attrKind)
		{
		case CompoundAttrKind_RefId:
			refId = attributes [1];
			break;

		case CompoundAttrKind_Kind:
			compoundKind = CompoundKindMap::findValue (attributes [1], CompoundKind_Undefined);
			break;
		}

		attributes += 2;
	}

	if (refId.isEmpty ())
	{
		// handle missing refid
		return true;
	}

	return parseCompound (refId);
}

bool
DoxygenIndexType::parseCompound (const char* refId)
{
	sl::String filePath = m_parser->getBaseDir () + "/" + refId + ".xml";

	DoxyXmlParser parser;
	return parser.parseFile (
		m_parser->getModule (),
		DoxyXmlFileKind_Compound,
		filePath
		);
}

//..............................................................................

bool
DoxygenCompoundType::create (
	DoxyXmlParser* parser,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;

	Module* module = m_parser->getModule ();

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_Version:
			if (module->m_version.isEmpty ())
			{
				module->m_version = attributes [1];
			}
			else if (module->m_version != attributes [1])
			{
				// handle version mismatch
			}

			break;
		}

		attributes += 2;
	}

	return true;
}

bool
DoxygenCompoundType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_CompoundDef:
		return m_parser->pushType <CompoundDefType> (name, attributes);
	}

	return true;
}

//..............................................................................

bool
CompoundDefType::create (
	DoxyXmlParser* parser,
	const char* name,
	const char** attributes
	)
{
	Module* module = parser->getModule ();

	m_parser = parser;
	m_compound = AXL_MEM_NEW (Compound);
	module->m_compoundList.insertTail (m_compound);

	sl::StringHashTableMapIterator <Compound*> mapIt;

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_Id:
			m_compound->m_id = attributes [1];
			mapIt = module->m_compoundMap.visit (m_compound->m_id);
			if (!mapIt->m_value)
			{
				mapIt->m_value = m_compound;
			}
			else
			{
				Compound* prevCompound = mapIt->m_value;
				printf (
					"duplicate compoud id: %s (%s: %s)\n",
					m_compound->m_id.sz (),
					getCompoundKindString (prevCompound->m_compoundKind),
					prevCompound->m_name.sz ()
					);

				if (prevCompound->m_detailedDescription.isEmpty () && prevCompound->m_briefDescription.isEmpty ())
				{
					printf ("  replacing old compound as it has no documentation\n");
					mapIt->m_value = m_compound;
				}
			}

			break;

		case AttrKind_Kind:
			m_compound->m_compoundKind = CompoundKindMap::findValue (attributes [1], CompoundKind_Undefined);
			break;

		case AttrKind_Language:
			m_compound->m_languageKind = LanguageKindMap::findValue (attributes [1], LanguageKind_Undefined);
			break;

		case AttrKind_Prot:
			m_compound->m_protectionKind = ProtectionKindMap::findValue (attributes [1], ProtectionKind_Undefined);
			break;

		case AttrKind_Final:
			m_compound->m_isFinal = BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes;
			break;

		case AttrKind_Sealed:
			m_compound->m_isSealed = BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes;
			break;

		case AttrKind_Abstract:
			m_compound->m_isAbstract = BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes;
			break;
		}

		attributes += 2;
	}

	switch (m_compound->m_compoundKind)
	{
	case CompoundKind_DoxyGroup:
		module->m_doxyGroupArray.append (m_compound);
		break;

	case CompoundKind_Namespace:
	case CompoundKind_Struct:
	case CompoundKind_Union:
	case CompoundKind_Class:
	case CompoundKind_Interface:
		module->m_namespaceArray.append (m_compound);
		break;
	}

	return true;
}

bool
CompoundDefType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	sl::BoxIterator <sl::String> stringIt;

	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_CompoundName:
		m_parser->pushType <StringType> (&m_compound->m_name, name, attributes);
		break;

	case ElemKind_Title:
		m_parser->pushType <StringType> (&m_compound->m_title, name, attributes);
		break;

	case ElemKind_BaseCompoundRef:
		m_parser->pushType <RefType> (&m_compound->m_baseRefList, name, attributes);
		break;

	case ElemKind_DerivedCompoundRef:
		m_parser->pushType <RefType> (&m_compound->m_derivedRefList, name, attributes);
		break;

	case ElemKind_Includes:
		stringIt = m_compound->m_importList.insertTail ();
		m_parser->pushType <StringType> (stringIt.p (), name, attributes);
		break;

	case ElemKind_IncludedBy:
	case ElemKind_IncDepGraph:
	case ElemKind_InvIncDepGraph:
		break;

	case ElemKind_InnerDir:
	case ElemKind_InnerFile:
	case ElemKind_InnerClass:
	case ElemKind_InnerNamespace:
	case ElemKind_InnerPage:
	case ElemKind_InnerGroup:
		m_parser->pushType <RefType> (&m_compound->m_innerRefList, name, attributes);
		break;

	case ElemKind_TemplateParamList:
		m_parser->pushType <TemplateParamListType> (&m_compound->m_templateParamList, name, attributes);
		break;

	case ElemKind_SectionDef:
		m_parser->pushType <SectionDefType> (m_compound, name, attributes);
		break;

	case ElemKind_BriefDescription:
		m_parser->pushType <DescriptionType> (&m_compound->m_briefDescription, name, attributes);
		break;

	case ElemKind_DetailedDescription:
		m_parser->pushType <DescriptionType> (&m_compound->m_detailedDescription, name, attributes);
		break;

	case ElemKind_InheritanceGraph:
	case ElemKind_CollaborationGraph:
	case ElemKind_ProgramListing:
	case ElemKind_Location:
	case ElemKind_ListOfAllMembers:
		break;
	}

	return true;
}

//..............................................................................

bool
RefType::create (
	DoxyXmlParser* parser,
	sl::StdList <Ref>* list,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_ref = AXL_MEM_NEW (Ref);
	list->insertTail (m_ref);

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_RefId:
			m_ref->m_id = attributes [1];
			break;

		case AttrKind_Prot:
			m_ref->m_protectionKind = ProtectionKindMap::findValue (attributes [1], ProtectionKind_Undefined);
			break;

		case AttrKind_Virt:
			m_ref->m_virtualKind = VirtualKindMap::findValue (attributes [1], VirtualKind_Undefined);
			break;
		}

		attributes += 2;
	}

	return true;
}

//..............................................................................

bool
SectionDefType::create (
	DoxyXmlParser* parser,
	Compound* parent,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_parent = parent;

	SectionKind sectionKind = SectionKind_Undefined;

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_Kind:
			sectionKind = SectionKindMap::findValue (attributes [1], SectionKind_Undefined);
			break;
		}

		attributes += 2;
	}

	return true;
}

bool
SectionDefType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_Header:
		break;

	case ElemKind_Description:
		// ignore description for SectionDefs
		break;

	case ElemKind_MemberDef:
		return m_parser->pushType <MemberDefType> (m_parent, name, attributes);
	}

	return true;
}

//..............................................................................

bool
MemberDefType::create (
	DoxyXmlParser* parser,
	Compound* parent,
	const char* name,
	const char** attributes
	)
{
	Module* module = parser->getModule ();

	m_parser = parser;
	m_member = AXL_MEM_NEW (Member);
	m_member->m_parentCompound = parent;
	parent->m_memberList.insertTail (m_member);

	sl::StringHashTableMapIterator <Member*> mapIt;
	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_Kind:
			m_member->m_memberKind = MemberKindMap::findValue (attributes [1], MemberKind_Undefined);
			break;

		case AttrKind_Id:
			m_member->m_id = attributes [1];
			if (parent->m_compoundKind == CompoundKind_DoxyGroup)
				break; // doxy groups contain duplicated definitions of members

			mapIt = module->m_memberMap.visit (m_member->m_id);
			if (!mapIt->m_value)
			{
				mapIt->m_value = m_member;
			}
			else
			{
				Member* prevMember = mapIt->m_value;
				printf (
					"duplicate member id %s (%s: %s)\n",
					m_member->m_id.sz (),
					getMemberKindString (prevMember->m_memberKind),
					prevMember->m_name.sz ()
					);

				if (prevMember->m_detailedDescription.isEmpty () && prevMember->m_briefDescription.isEmpty ())
				{
					printf ("  replacing old member as it has no documentation\n");
					mapIt->m_value = m_member;
				}
			}

			break;

		case AttrKind_Prot:
			m_member->m_protectionKind = ProtectionKindMap::findValue (attributes [1], ProtectionKind_Undefined);
			break;

		case AttrKind_Static:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Static;
			break;

		case AttrKind_Const:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Const;
			break;

		case AttrKind_Explicit:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Explicit;
			break;

		case AttrKind_Inline:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Inline;
			break;

		case AttrKind_Virtual:
			m_member->m_virtualKind = VirtualKindMap::findValue (attributes [1], VirtualKind_Undefined);
			break;

		case AttrKind_Volatile:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Volatile;
			break;

		case AttrKind_Mutable:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Mutable;
			break;

		case AttrKind_Readable:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Readable;
			break;

		case AttrKind_Writeable:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Writeable;
			break;

		case AttrKind_InitOnly:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_InitOnly;
			break;

		case AttrKind_Settable:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Settable;
			break;

		case AttrKind_Gettable:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Gettable;
			break;

		case AttrKind_Final:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Final;
			break;

		case AttrKind_Sealed:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Sealed;
			break;

		case AttrKind_New:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_New;
			break;

		case AttrKind_Add:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Add;
			break;

		case AttrKind_Remove:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Remove;
			break;

		case AttrKind_Raise:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Raise;
			break;

		case AttrKind_Optional:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Optional;
			break;

		case AttrKind_Required:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Required;
			break;

		case AttrKind_Accessor:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Accessor;
			break;

		case AttrKind_Attribute:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Attribute;
			break;

		case AttrKind_Property:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Property;
			break;

		case AttrKind_ReadOnly:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_ReadOnly;
			break;

		case AttrKind_Bound:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Bound;
			break;

		case AttrKind_Removable:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Removable;
			break;

		case AttrKind_Contrained:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Contrained;
			break;

		case AttrKind_Transient:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_Transient;
			break;

		case AttrKind_MaybeVoid:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_MaybeVoid;
			break;

		case AttrKind_MaybeDefault:
			if (BoolKindMap::findValue (attributes [1], BoolKind_Undefined) == BoolKind_Yes)
				m_member->m_flags |= MemberFlag_MaybeDefault;
			break;
		}

		attributes += 2;
	}

	return true;
}

bool
MemberDefType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	sl::BoxIterator <sl::String> stringIt;

	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_Includes:
		stringIt = m_member->m_importList.insertTail ();
		m_parser->pushType <StringType> (stringIt.p (), name, attributes);
		break;

	case ElemKind_TemplateParamList:
		m_parser->pushType <TemplateParamListType> (&m_member->m_templateParamList, name, attributes);
		break;

	case ElemKind_Type:
		m_parser->pushType <LinkedTextType> (&m_member->m_type, name, attributes);
		break;

	case ElemKind_Definition:
		m_parser->pushType <StringType> (&m_member->m_definition, name, attributes);
		break;

	case ElemKind_ArgString:
		m_parser->pushType <StringType> (&m_member->m_argString, name, attributes);
		break;

	case ElemKind_Name:
		m_parser->pushType <StringType> (&m_member->m_name, name, attributes);
		break;

	case ElemKind_Read:
	case ElemKind_Write:
		break;

	case ElemKind_BitField:
		m_parser->pushType <StringType> (&m_member->m_bitField, name, attributes);
		break;

	case ElemKind_Initializer:
		m_parser->pushType <LinkedTextType> (&m_member->m_initializer, name, attributes);
		break;

	case ElemKind_Exceptions:
		m_parser->pushType <LinkedTextType> (&m_member->m_exceptions, name, attributes);
		break;

	case ElemKind_Reimplements:
	case ElemKind_ReimplementedBy:
		break;

	case ElemKind_Param:
		m_parser->pushType <ParamType> (&m_member->m_paramList, name, attributes);
		break;

	case ElemKind_EnumValue:
		m_parser->pushType <EnumValueType> (m_member, name, attributes);
		break;

	case ElemKind_BriefDescription:
		m_parser->pushType <DescriptionType> (&m_member->m_briefDescription, name, attributes);
		break;

	case ElemKind_DetailedDescription:
		m_parser->pushType <DescriptionType> (&m_member->m_detailedDescription, name, attributes);
		break;

	case ElemKind_InBodyDescription:
		m_parser->pushType <DescriptionType> (&m_member->m_inBodyDescription, name, attributes);
		break;

	case ElemKind_Location:
	case ElemKind_References:
	case ElemKind_ReferencedBy:
		break;

	case ElemKind_Modifiers:
		m_parser->pushType <StringType> (&m_member->m_modifiers, name, attributes);
		break;
	}

	return true;
}

//..............................................................................

bool
DescriptionType::create (
	DoxyXmlParser* parser,
	Description* description,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_description = description;
	return true;
}

bool
DescriptionType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
		DocParagraphBlock* paragraphBlock;

	case ElemKind_Title:
		m_parser->pushType <StringType> (&m_description->m_title, name, attributes);
		break;

	case ElemKind_Para:
		paragraphBlock = AXL_MEM_NEW (DocParagraphBlock);
		paragraphBlock->m_blockKind = DocBlockKind_Paragraph;
		m_description->m_docBlockList.insertTail (paragraphBlock);
		m_parser->pushType <DocParaType> (paragraphBlock, name, attributes);
		break;

	case ElemKind_Sect1:
		m_parser->pushType <DocSectionBlockType> (&m_description->m_docBlockList, name, attributes);
		break;

	case ElemKind_Internal:
		m_parser->pushType <DocInternalBlockType> (&m_description->m_docBlockList, name, attributes);
		break;
	}

	return true;
}

//..............................................................................

bool
DocSectionBlockType::create (
	DoxyXmlParser* parser,
	sl::StdList <DocBlock>* list,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_sectionBlock = AXL_MEM_NEW (DocSectionBlock);
	m_sectionBlock->m_blockKind = m_blockKind;
	list->insertTail (m_sectionBlock);

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_Id:
			m_sectionBlock->m_id = attributes [1];
			break;
		}

		attributes += 2;
	}

	return true;
}

bool
DocSectionBlockType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
		DocParagraphBlock* paragraphBlock;

	case ElemKind_Title:
		m_parser->pushType <StringType> (&m_sectionBlock->m_title, name, attributes);
		break;

	case ElemKind_Para:
		paragraphBlock = AXL_MEM_NEW (DocParagraphBlock);
		m_sectionBlock->m_childBlockList.insertTail (paragraphBlock);
		m_parser->pushType <DocParaType> (paragraphBlock, name, attributes);
		break;

	case ElemKind_Sect1:
	case ElemKind_Sect2:
	case ElemKind_Sect3:
	case ElemKind_Sect4:
		m_parser->pushType <DocSectionBlockType> (&m_sectionBlock->m_childBlockList, name, attributes);
		break;

	case ElemKind_Internal:
		m_parser->pushType <DocInternalBlockType> (&m_sectionBlock->m_childBlockList, name, attributes);
		break;

	}

	return true;
}

//..............................................................................

bool
EnumValueType::create (
	DoxyXmlParser* parser,
	Member* member,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_enumValue = AXL_MEM_NEW (EnumValue);
	member->m_enumValueList.insertTail (m_enumValue);

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_Id:
			m_enumValue->m_id = attributes [1];
			break;

		case AttrKind_Prot:
			m_enumValue->m_protectionKind = ProtectionKindMap::findValue (attributes [1], ProtectionKind_Undefined);
			break;
		}

		attributes += 2;
	}

	return true;
}

bool
EnumValueType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_Name:
		m_parser->pushType <StringType> (&m_enumValue->m_name, name, attributes);
		break;

	case ElemKind_Initializer:
		m_parser->pushType <LinkedTextType> (&m_enumValue->m_initializer, name, attributes);
		break;

	case ElemKind_BriefDescription:
		m_parser->pushType <DescriptionType> (&m_enumValue->m_briefDescription, name, attributes);
		break;

	case ElemKind_DetailedDescription:
		m_parser->pushType <DescriptionType> (&m_enumValue->m_detailedDescription, name, attributes);
		break;
	}

	return true;
}

//..............................................................................

bool
TemplateParamListType::create (
	DoxyXmlParser* parser,
	sl::StdList <Param>* list,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_list = list;
	return true;
}

bool
TemplateParamListType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_Param:
		m_parser->pushType <ParamType> (m_list, name, attributes);
		break;
	}

	return true;
}

//..............................................................................

bool
ParamType::create (
	DoxyXmlParser* parser,
	sl::StdList <Param>* list,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_param = AXL_MEM_NEW (Param);
	list->insertTail (m_param);

	return true;
}

bool
ParamType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_Type:
		m_parser->pushType <LinkedTextType> (&m_param->m_type, name, attributes);
		break;

	case ElemKind_DeclName:
		m_parser->pushType <StringType> (&m_param->m_declarationName, name, attributes);
		break;

	case ElemKind_DefName:
		m_parser->pushType <StringType> (&m_param->m_definitionName, name, attributes);
		break;

	case ElemKind_Array:
		m_parser->pushType <StringType> (&m_param->m_array, name, attributes);
		break;

	case ElemKind_DefVal:
		m_parser->pushType <LinkedTextType> (&m_param->m_defaultValue, name, attributes);
		break;

	case ElemKind_TypeConstraint:
		m_parser->pushType <LinkedTextType> (&m_param->m_typeConstraint, name, attributes);
		break;

	case ElemKind_BriefDescription:
		m_parser->pushType <DescriptionType> (&m_param->m_briefDescription, name, attributes);
		break;
	}

	return true;
}

//..............................................................................

bool
LinkedTextType::create (
	DoxyXmlParser* parser,
	LinkedText* linkedText,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_linkedText = linkedText;
	m_refText = AXL_MEM_NEW (RefText);
	m_linkedText->m_refTextList.insertTail (m_refText);

	return true;
}

bool
LinkedTextType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_Ref:
		m_parser->pushType <RefTextType> (m_linkedText, name, attributes);
		break;
	}

	m_refText = AXL_MEM_NEW (RefText);
	m_linkedText->m_refTextList.insertTail (m_refText);
	return true;
}

//..............................................................................

bool
RefTextType::create (
	DoxyXmlParser* parser,
	LinkedText* linkedText,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_refText = AXL_MEM_NEW (RefText);
	linkedText->m_refTextList.insertTail (m_refText);

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_RefId:
			m_refText->m_id = attributes [1];
			break;

		case AttrKind_KindRef:
			m_refText->m_refKind = RefKindMap::findValue (attributes [1], RefKind_Undefined);
			break;

		case AttrKind_External:
			m_refText->m_external = attributes [1];
			break;

		case AttrKind_Tooltip:
			m_refText->m_tooltip = attributes [1];
			break;
		}

		attributes += 2;
	}

	return true;
}

//..............................................................................

bool
DocParaType::create (
	DoxyXmlParser* parser,
	DocParagraphBlock* paragraphBlock,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_paragraphBlock = paragraphBlock;
	m_childBlock = AXL_MEM_NEW (DocBlock);
	m_paragraphBlock->m_childBlockList.insertTail (m_childBlock);

	return true;
}

bool
DocParaType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	DocBlock* block;

	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
	case ElemKind_Ref:
		m_parser->pushType <DocRefTextType> (&m_paragraphBlock->m_childBlockList, name, attributes);
		break;

	case ElemKind_SimpleSect:
		m_parser->pushType <DocSimpleSectionType> (&m_paragraphBlock->m_childBlockList, name, attributes);
		break;

	default:
		block = AXL_MEM_NEW (DocBlock);
		block->m_blockDoxyKind = name;
		m_paragraphBlock->m_childBlockList.insertTail (block);
		m_parser->pushType <DocTextType> (block, name, attributes);
	}

	m_childBlock = AXL_MEM_NEW (DocBlock);
	m_paragraphBlock->m_childBlockList.insertTail (m_childBlock);
	return true;
}

//..............................................................................

bool
DocRefTextType::create (
	DoxyXmlParser* parser,
	sl::StdList <DocBlock>* list,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_refBlock = AXL_MEM_NEW (DocRefBlock);
	list->insertTail (m_refBlock);

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_RefId:
			m_refBlock->m_id = attributes [1];
			break;

		case AttrKind_KindRef:
			m_refBlock->m_refKind = RefKindMap::findValue (attributes [1], RefKind_Undefined);
			break;

		case AttrKind_External:
			m_refBlock->m_external = attributes [1];
			break;
		}

		attributes += 2;
	}

	return true;
}

//..............................................................................

bool
DocTextType::create (
	DoxyXmlParser* parser,
	DocBlock* block,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_block = block;
	return true;
}

//..............................................................................

bool
DocSimpleSectionType::create (
	DoxyXmlParser* parser,
	sl::StdList <DocBlock>* list,
	const char* name,
	const char** attributes
	)
{
	m_parser = parser;
	m_sectionBlock = AXL_MEM_NEW (DocSimpleSectionBlock);
	list->insertTail (m_sectionBlock);

	while (*attributes)
	{
		AttrKind attrKind = AttrKindMap::findValue (attributes [0], AttrKind_Undefined);
		switch (attrKind)
		{
		case AttrKind_Kind:
			m_sectionBlock->m_simpleSectionKind = DocSimpleSectionKindMap::findValue (attributes [1], DocSimpleSectionKind_Undefined);
			break;
		}

		attributes += 2;
	}

	return true;
}

bool
DocSimpleSectionType::onStartElement (
	const char* name,
	const char** attributes
	)
{
	ElemKind elemKind = ElemKindMap::findValue (name, ElemKind_Undefined);
	switch (elemKind)
	{
		DocParagraphBlock* paragraphBlock;

	case ElemKind_Para:
		paragraphBlock = AXL_MEM_NEW (DocParagraphBlock);
		m_sectionBlock->m_childBlockList.insertTail (paragraphBlock);
		m_parser->pushType <DocParaType> (paragraphBlock, name, attributes);
		break;
	}

	return true;
}

//..............................................................................
