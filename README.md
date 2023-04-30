## Introduction

To parse XML data, a so-called DOM parser is usually used - e.g. the Microsoft.XMLDOM object.
This parser goes through the entire structure and rebuilds it hierarchically in its own data structure.
Afterwards you can continue working on this basis.

In other programming languages, however, one occasionally encounters a different approach: the SAX parser.
Here the idea is as follows:
The parser traverses the XML string and calls user-defined functions at certain breakpoints.
Usually this would be at the beginning of an element, for example.
The parser then passes the element type, the position in the string and the attributes of the element to the user-defined function.
The parser doesn't care what the user does with it - it just calls functions at the breakpoints.
Further breakpoints would be when closing an element or as soon as the content of an element has been reached.

This approach has advantages as well as disadvantages.
The advantage is that the user can decide what is really needed and what is not.
This can result in faster parsing.
Also it is possible to process the data before it is completely loaded or processed.

The disadvantage however is that the work with this can not only take some getting used to but also quickly become very complex.
In particular, since it is important for a reasonable processing to exchange information between the individual user functions one will have to use global variables.

## Example of use:
The following example reads the Autoitscript.com forum page and extracts a list of recent topics using the SAX parser:

```Autoit
#include "SAX.au3"
#include <Array.au3>

; read the xml data (example job here: read out the latest topics from the autoitscript forum)
Local $sXMLData = BinaryToString(InetRead("https://www.autoitscript.com/forum/"))

; global user-defined variables to communicate between the callback functions
Global $mLatestTopics[] ; map for the result

; process the xml-file
_xml_SAXParse($sXMLData, 1, __elementsStart)

; Prepare the results for showing in a _ArrayDisplay-window
Global $aTopicList[UBound($mLatestTopics)][2], $iC = 0
For $mTitle In MapKeys($mLatestTopics)
    $aTopicList[$iC][0] = $mTitle
    $aTopicList[$iC][1] = $mLatestTopics[$mTitle]
    $iC += 1
Next
_ArrayDisplay($aTopicList, "Latest Topics", "", 64+16, "|", "Topic|Link")



#region user-defined callback functions for handling the xml via SAX-parser

; is called when a new XML element starts
Func __elementsStart($sElementName, $mAttributes, $iStart, $iLen, $bSelfClosing)
    If $sElementName = "a" And StringInStr($mAttributes["class"], 'ipsDataItem_title', 1, 1) Then
        $mLatestTopics[StringTrimLeft($mAttributes["title"], 15)] = $mAttributes["href"]
    EndIf
EndFunc

#endRegion
```
## To use or not?

So what's the point of all this?
For most use cases I think it is better to use the known DOM-based approaches, because working with a SAX parser can quickly degenerate into enormous complexity.

However, a certain acceleration can(!) be achieved with this approach.
I have tested this in the example above:
If I process the page with the HTMLFile object, it needs ~150ms for parsing alone.
The topics were already processed with the SAX parser after 60ms (the parsing continues - but can be stopped).
The question is whether the higher complexity for the user is worth it for these cases.

The Sax parser also reacts more kindly to errors in the XML file in many cases and could be used as a more robust alternative.

With the SAX parser as a fundament, it should also be fairly easy to write your own purely AutoIt-based DOM parser.

And last but not least, we can now say for AutoIt: Now we have our own Sax parser too!