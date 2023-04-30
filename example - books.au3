#include "SAX.au3"

; global user-defined variables to communicate between the callback functions and implement a common process structure
Global $_sax_mBookList[], $_sax_mBook, $_sax_bBook = False, $_sax_CurrentAttribute

; read the xml file (example job here: create list of book-objects out of the xml file)
Local $sXMLData = FileRead("Test.xml")

; parse the xml-file
_xml_SAXParse($sXMLData, 3, __elementsStart, __elementsEnd, __contentOccurs)

; process the result:
For $mBook In $_sax_mBookList
	ConsoleWrite(@CRLF & "------------------------------------------------------------------" & @CRLF)
	For $sAttribute In MapKeys($mBook)
		ConsoleWrite(StringFormat("% 13s: %s\n", $sAttribute, StringStripWS(StringReplace(StringStripCR($mBook[$sAttribute]), @LF, "", 0, 1), 7)))
	Next
	ConsoleWrite("==================================================================" & @CRLF)
Next



#region user-defined callback functions for handling the xml via SAX-parser

; is called when a new XML element starts
Func __elementsStart($sElementName, $mAttributes, $iStart, $iLen, $bSelfClosing)
	If $sElementName = "book" Then	; a new book inside the xml is start to be processed
		; new empty map for book object
		Global $_sax_mBook[]
		$_sax_bBook = True
	ElseIf $_sax_bBook Then
		$_sax_CurrentAttribute = $sElementName
	EndIf
EndFunc

; is called when an XML element is closed
Func __elementsEnd($sElementName, $iStart, $iLen)
	If $sElementName = "book" Then	; a book object is finished
		; add current book-map to result list
		MapAppend($_sax_mBookList, $_sax_mBook)
		$_sax_bBook = False
	EndIf
EndFunc

; is called when element content is being processed
Func __contentOccurs($sContent, $iStart, $iLen)
	If $_sax_bBook Then $_sax_mBook[$_sax_CurrentAttribute] &= $sContent
EndFunc

#endRegion