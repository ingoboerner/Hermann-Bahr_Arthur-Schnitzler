xquery version "3.1";

import module namespace config="http://hbas.at/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "text";
declare option output:media-type "text/csv";


let $data := collection($config:data-root || "/meta")/id("Werke")
let $notes := $data//tei:notesStmt/tei:note

let $output := 
    for $note in $notes
    let $id := $note/ancestor::tei:biblFull/@xml:id/string()
    let $external-link := $note/string()
    let $title := $note/ancestor::tei:biblFull/tei:titleStmt/tei:title/text()
    
    return
       
        '"' || $id|| '";"' || $title || '";"' || $external-link || '"&#xa;'
        
    return 
         ('"id";"title";"external-link"$#xa;',
         $output)