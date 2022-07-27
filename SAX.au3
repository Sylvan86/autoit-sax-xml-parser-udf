#include-once
; #INDEX# =======================================================================================================================
; Title .........: SAX XML parsing UDF
; Version .......: 0.1
; AutoIt Version : 3.3.16.0
; Language ......: english (german maybe by accident)
; Description ...: provide structures to parse a xml string event-driven according to the SAX-standard
; Author(s) .....: AspirinJunkie
; Last changed ..: 2022-07-27
; Link ..........: existiert noch nicht
; ===============================================================================================================================


; #FUNCTION# ======================================================================================
; Name ..........: _xml_SAXParse()
; Description ...: parse xml strings according to the SAX standard; SAX is event-driven and operate on each piece of the XML document sequentially
; Syntax ........: _xml_SAXParse($sXML[, $cbStartElement = Default[, $cbEndElement = Default[, $cbCharacters = Default[, $cbXMLDefinition = Default[, $cbCDATA = Default[, $dFlags = 1]]]]]])
; Parameters ....: $sXML            - the input xml string
;                  $cbStartElement  - [optional] callback function for handling xml open-tags with 5 parameters: (default:Default)
;                  |1st element name
;                  |2nd element attributes as a autoit map [Key-Value]
;                  |3rd start offset in the in the source xml string
;                  |4th string len of open tag in the source xml string
;                  |5th boolean value indicating if element is a self-closing element
;                  $cbEndElement    - [optional] callback function for handling xml closing-tags with 3 parameters: (default:Default)
;                  |1st: element name
;                  |2nd: start offset in the in the source xml string
;                  |3rd: string len of open tag in the source xml string
;                  $cbCharacters    - [optional] callback function for handling xml element content with 3 parameters: (see dFlags for handling whitespaces) (default:Default)
;                  |1st: content as string
;                  |2nd: start offset in the in the source xml string
;                  |3rd: string len of open tag in the source xml string
;                  $cbXMLDefinition - [optional] callback function for handling xml definition elements with 3 parameters (default:Default)
;                  $cbCDATA         - [optional] callback function for handling CDATA elements with 3 parameters (default:Default)
;                  $dFlags          - [optional] bit mask with following options: (default:1)
;                  |1: whitespace only content is beeing ignored
;                  |2: comments get removed before parsing
; Return values .: Success: True
;                  Failure: False and set @error to:
;                  |@error = 1: error during parsing element start
;                  |@error = 2: error during parsing element end
;                  |@error = 3: report worthy error - should actually not occur
; Author ........: AspirinJunkie
; Modified ......: 2022-07-27
; =================================================================================================
Func _xml_SAXParse(ByRef $sXML, $cbStartElement = Default, $cbEndElement = Default, $cbCharacters = Default, $cbXMLDefinition = Default, $cbCDATA = Default, $dFlags = 1)
	Local $iPos = 1, $iPosBefore, $sMatch
	Local $sElName, $aAttributes, $sAttrib, $aSplit

	Local Const $sRE = '(?x)' & _
						'(?(DEFINE)' & _
						'   (?<WS> [\x20\x{9}\x{D}\x{A}] )' & _
						'   (?<Char> [\x{9}\x{A}\x{D}\x20-\x{D7FF}\x{E000}-\x{FFFD}] )' & _
						'   (?<NameStartChar> [:A-Z_a-z\xC0-\xD6\xD8-\xF6\xF8-\x{2FF}\x{370}-\x{37D}\x{37F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}] )' & _
						'   (?<NameChar> (?:\g<NameStartChar>|[-\.0-9\xB7\x{0300}-\x{036F}\x{203F}-\x{2040}]) )' & _
						'   (?<Name> \g<NameStartChar>\g<NameChar>* )' & _
						'   (?<EntityRef> (?:\&\g<Name>;) )' & _
						'   (?<PEReference> (?:\%\g<Name>;) )' & _
						'   (?<Reference> (?:\g<EntityRef>|\g<PEReference>) )' & _
						'   (?<AttValue> (?:\"(?:[^<&\"]|\g<Reference>)*\"|\''(?:[^<&'']|\g<Reference>)*\'') )' & _
						'   (?<AttPlusValue> \g<WS>*(?:["'']?(\g<Name>)["'']?\g<WS>*(?:=\g<WS>*(\g<AttValue>))*) )' & _
						'   (?<ElementBegin> <\g<Name>\g<AttPlusValue>*\/?> )' & _
						'   (?<ElementEnd> <\/\g<Name>?> )' & _
						'   (?<Comment> (?sm)<!--((?!--)\g<Char>)*--> )' & _
						'   (?<ScriptElement> (?sm)(?:<(?>script|style)\b.+?)(?R)?(?:<\/(?>script|style)>) )' & _
						'   (?<NonParsingElement> (?sm)(?:<!\[CDATA\[.+?)(?R)?(?:\]\]>) )' & _
						'   (?<XMLDefinition> (?sm)<[!?]\g<Name>[^>]*> )' & _
						')' ; https://regex101.com/r/CGQVZg/4

	;  remove comments:
	If BitAND($dFlags, 2) Then $sXML = StringRegExpReplace($sXML, $sRE & "(?P>Comment)", "")
	If @error Then MsgBox(0, "", @error)

	Local $iXMLLength = StringLen($sXML)

	Do
		;  XML definition elements like '<?xml version="1.0"?>' or '<!DOCTYPE ...>' and other non content elements
		If __matchAndBool($sMatch, $sXML, $sRE & '\G(?P>XMLDefinition)', $iPos) Then
			$iPosBefore = $iPos
			$iPos = @extended

			If IsKeyword($cbXMLDefinition) <> 1 Then $cbXMLDefinition($sMatch, $iPosBefore, $iPos - $iPosBefore)

		; Elements which should not be parsed (CDATA)
		ElseIf __matchAndBool($sMatch, $sXML, $sRE & '\G(?P>NonParsingElement)', $iPos) Then
			$iPosBefore = $iPos
			$iPos = @extended

			If IsKeyword($cbCDATA) <> 1 Then $cbCDATA($sMatch, $iPosBefore, $iPos - $iPosBefore)

		; element start
		ElseIf __matchAndBool($sMatch, $sXML, $sRE & '\G(?P>ElementBegin)', $iPos) Then
			$iPosBefore = $iPos
			$iPos = @extended
			Local $mAttributes[]

			__matchAndBool($sElName, $sMatch, $sRE & '\A\<\K(?P>Name)')
			If @error Then Return SetError(1, $iPos, False)

			$aAttributes = StringRegExp(StringTrimLeft($sMatch, StringLen($sElName) + 1), $sRE & '(?P>WS)*\K(?P>AttPlusValue)', 3)
			If Not @error Then
				For $sAttrib In $aAttributes
					$aSplit = StringSplit($sAttrib, "=", 3)
					$mAttributes[__remQuote($aSplit[0])] = UBound($aSplit) > 1 ? __remQuote($aSplit[1]) : ""
				Next
			EndIf
			If IsKeyword($cbStartElement) <> 1 Then $cbStartElement($sElName, $mAttributes, $iPosBefore, $iPos - $iPosBefore, StringRight($sMatch, 2) == "/>")

		; element closing
		ElseIf __matchAndBool($sMatch, $sXML, $sRE & '\G(?P>ElementEnd)', $iPos) Then
			$iPosBefore = $iPos
			$iPos = @extended

			__matchAndBool($sElName, $sMatch, $sRE & '\A\<\/\K(?P>Name)')
			If @error Then Return SetError(2, $iPos, False)

			If IsKeyword($cbEndElement) <> 1 Then $cbEndElement($sElName, $iPosBefore, $iPos - $iPosBefore)

		; element content
		ElseIf __matchAndBool($sMatch, $sXML, $sRE & '\G[^<]++', $iPos) Then
			$iPosBefore = $iPos
			$iPos = @extended

			If Not BitAND($dFlags, StringIsSpace($sMatch)) And IsKeyword($cbCharacters) <> 1 Then $cbCharacters($sMatch, $iPosBefore, $iPos - $iPosBefore)

		; should normally only match the document end
		Else
			$iPos += 1

			Return $iPos > $iXMLLength ? True : SetError(3, $iPos, False)
		EndIf

	Until 0
EndFunc   ;==>_xml_SAXParse


; #FUNCTION# ======================================================================================
; Name ..........: __remQuote()
; Description ...: remove trailing and leading quotes and whitespaces from a string
; Syntax ........: __remQuote($sString)
; Parameters ....: $sString - input string
; Return values .: the string where the leading/trailing quotes are removed
; Author ........: AspirinJunkie
; Remarks .......: whitespaces are only removed if the are outside the quotes
; =================================================================================================
Func __remQuote($sString)
	Return StringRegExpReplace($sString, '(^\h*["'']|["'']\h*$)', "", 2)
EndFunc

; #FUNCTION# ======================================================================================
; Name ..........: __matchAndBool()
; Description ...: get first regex match, return true/false and offset to @extended in one set
; Syntax ........: __matchAndBool(ByRef $o_Tmp, Const ByRef $s_String, Const $s_Pattern[, $i_Os = 1])
; Parameters ....: ByRef $o_Tmp          - user byref variable where to store the first match
;                  Const ByRef $s_String - input string
;                  Const $s_Pattern      - regular expression pattern
;                  $i_Os                 - [optional] offset parameter from StringRegExp (default:1)
; Return values .: Success: True and set @extended to next offset
;                  Failure: False and set @error to 1
; Author ........: AspirinJunkie
; Remarks .......: internal helper function only
; =================================================================================================
Func __matchAndBool(ByRef $o_Tmp, Const ByRef $s_String, Const $s_Pattern, $i_Os = 1)
	Local $a_Return = StringRegExp($s_String, $s_Pattern, 1, $i_Os)
	If @error Then Return SetError(1, $i_Os, False)
	$o_Tmp = $a_Return[0]
	Return SetExtended(@extended, True)
EndFunc   ;==>__matchAndBool
