#include-once
; #INDEX# =======================================================================================================================
; Title .........: SAX XML parsing UDF
; Version .......: 0.2
; AutoIt Version : 3.3.16.0
; Language ......: english (german maybe by accident)
; Description ...: provide structures to parse a xml string event-driven according to the SAX-standard
; Author(s) .....: AspirinJunkie
; Last changed ..: 2022-07-28
; Link ..........: https://autoit.de/thread/87771-sax-xml-parser-anderer-parsing-ansatz-f%C3%BCr-die-behandlung-von-xml-daten/
; ===============================================================================================================================


; #FUNCTION# ======================================================================================
; Name ..........: _xml_SAXParse()
; Description ...: parse xml strings according to the SAX standard; SAX is event-driven and operate on each piece of the XML document sequentially
; Syntax ........: _xml_SAXParse($sXML[, $cbStartElement = Default[, $cbEndElement = Default[, $cbCharacters = Default[, $cbXMLDefinition = Default[, $cbCDATA = Default[, $dFlags = 1]]]]]])
; Parameters ....: $sXML            - the input xml string
;                  $dFlags          - [optional] bit mask with following options: (default:1)
;                  		1: whitespace only content is beeing ignored
;                  		2: comments get removed before parsing
;                  $cbStartElement  - [optional] callback function for handling xml open-tags with 5 parameters: (default:Default)
;                  		1st element name
;                  		2nd element attributes as a autoit map [Key-Value]
;                  		3rd start offset in the in the source xml string
;                  		4th string len of open tag in the source xml string
;                  		5th boolean value indicating if element is a self-closing element
;                  $cbEndElement    - [optional] callback function for handling xml closing-tags with 3 parameters: (default:Default)
;                  		1st: element name
;                  		2nd: start offset in the in the source xml string
;                  		3rd: string len of open tag in the source xml string
;                  $cbCharacters    - [optional] callback function for handling xml element content with 3 parameters: (see dFlags for handling whitespaces) (default:Default)
;                  		1st: content as string
;                  		2nd: start offset in the in the source xml string
;                  		3rd: string len of open tag in the source xml string
;                  $cbXMLDefinition - [optional] callback function for handling xml definition elements with 3 parameters (default:Default)
;                  $cbCDATA         - [optional] callback function for handling CDATA elements with 3 parameters (default:Default)
;                  $cbSpecial       - [optional] callback function for handling special elements defined in $sSpecialElements (default:Default)
;                  $sSpecialElements- [optional] pipe("|") separated list of xml-elements which should processed special (e.g.: script|style) (default:Default)
; Return values .: Success: True
;                  Failure: False and set @error to:
;                  		@error = 1: error during parsing element start
;                  		@error = 2: error during parsing element end
;                  		@error = 3: report worthy error - should actually not occur
; Author ........: AspirinJunkie
; Modified ......: 2022-07-28
; =================================================================================================
Func _xml_SAXParse(ByRef $sXML, $dFlags = 3, $cbStartElement = Default, $cbEndElement = Default, $cbCharacters = Default, $cbXMLDefinition = Default, $cbCDATA = Default, $cbSpecial = Default, $sSpecialElements = Default)
	Local $iPos = 1, $iPosBefore, $sMatch, $sBeginChars
	Local $sElName, $aAttributes, $sAttrib, $aSplit

	; pattern based on: https://regex101.com/r/CGQVZg/9
	Local 	$patElementBegin = '\G<[[:alpha:]_][\w:\.-]*+\s*[^>]*>', _
			$patElementEnd = '\G<\/(?>[[:alpha:]_][\w:\.-]*+)?\s*>', _
			$patAttributes = '\G\s+\K\s*+[[:alpha:]_][\w:\.-]*+\s*+(?>=\s*(?>\"[^\"]*+\"|\''[^\'']*+\''))*+', _
			$patScriptElement = '\G(?s)<(?>' & $sSpecialElements & ')\b.+?<\/(?>' & $sSpecialElements & ')>', _
			$patXMLDefinition = '\G(?s)\<[!?][^>]*>', _
			$patNonParsing = '\G(?s)<!\[CDATA\[.+?\]\]>', _
			$patComment = '(?s)<!--.+?-->'

	;  remove comments:
	If BitAND($dFlags, 2) Then $sXML = StringRegExpReplace($sXML, $patComment, "")

	Local $iXMLLength = StringLen($sXML)
	Do
		; prefiltering for performance-reasons
		$sBeginChars = StringMid($sXML, $iPos, 2)
		If StringLeft($sBeginChars, 1) = "<" Then

			If StringInStr("?!", StringRight($sBeginChars, 1), 1) Then
				; Elements which should not be parsed (CDATA)
				If __matchAndBool($sMatch, $sXML, $patNonParsing, $iPos) Then
					$iPosBefore = $iPos
					$iPos = @extended

					If IsKeyword($cbCDATA) <> 1 Then $cbCDATA($sMatch, $iPosBefore, $iPos - $iPosBefore)

				;  XML definition elements like '<?xml version="1.0"?>' or '<!DOCTYPE ...>' and other non content elements
				ElseIf __matchAndBool($sMatch, $sXML, $patXMLDefinition, $iPos) Then
					$iPosBefore = $iPos
					$iPos = @extended

					If IsKeyword($cbXMLDefinition) <> 1 Then $cbXMLDefinition($sMatch, $iPosBefore, $iPos - $iPosBefore)
				EndIf
			Else
				If IsString($sSpecialElements) And __matchAndBool($sMatch, $sXML, $patScriptElement, $iPos) Then
					$iPosBefore = $iPos
					$iPos = @extended

					If IsKeyword($cbSpecial) <> 1 Then $cbSpecial($sMatch, $iPosBefore, $iPos - $iPosBefore)

				; element start
				ElseIf __matchAndBool($sMatch, $sXML, $patElementBegin, $iPos) Then
					$iPosBefore = $iPos
					$iPos = @extended
					Local $mAttributes[]

					__matchAndBool($sElName, $sMatch, '\A<\K[[:alpha:]_][\w:\.-]*+')
					If @error Then Return SetError(1, $iPos, False)

					$aAttributes = StringRegExp(StringTrimLeft($sMatch, StringLen($sElName) + 1), $patAttributes, 3)
					If Not @error Then
						For $sAttrib In $aAttributes
							$aSplit = StringSplit($sAttrib, "=", 3)
							$mAttributes[__remQuote($aSplit[0])] = UBound($aSplit) > 1 ? __remQuote($aSplit[1]) : ""
						Next
					EndIf
					If IsKeyword($cbStartElement) <> 1 Then $cbStartElement($sElName, $mAttributes, $iPosBefore, $iPos - $iPosBefore, StringRight($sMatch, 2) == "/>")

				; element closing
				ElseIf __matchAndBool($sMatch, $sXML, $patElementEnd, $iPos) Then
					$iPosBefore = $iPos
					$iPos = @extended

					__matchAndBool($sElName, $sMatch, '\A<\/\K[[:alpha:]_][\w:\.-]*+')
					If @error Then Return SetError(2, $iPos, False)

					If IsKeyword($cbEndElement) <> 1 Then $cbEndElement($sElName, $iPosBefore, $iPos - $iPosBefore)
				Else
					$iPos += 1
					If $iPos > $iXMLLength Then Return True
				EndIf
			EndIf

		; element content
		ElseIf __matchAndBool($sMatch, $sXML, '\G[^<]+', $iPos) Then
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
EndFunc   ;==>__remQuote

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
Func __matchAndBool(ByRef $o_Tmp, ByRef $s_String, Const $s_Pattern, $i_Os = 1)
	Local $a_Return = StringRegExp($s_String, $s_Pattern, 1, $i_Os)
	If @error Then Return SetError(1, $i_Os, False)
	$o_Tmp = $a_Return[0]
	Return SetExtended(@extended, True)
EndFunc   ;==>__matchAndBool